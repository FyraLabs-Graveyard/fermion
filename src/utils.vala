namespace Fermion.Utils {
    public delegate void SelectionCallback (string uri);

    public AppInfo? get_default_app_for_uri (string? uri) {
        if (uri == null)
            return null;

        AppInfo? info = null;
        var scheme = Uri.parse_scheme (uri);
        if (scheme != null)
            info = AppInfo.get_default_for_uri_scheme (scheme);

        // unlucky tbh
        if (info == null) {
            bool uncertain;

            var type = ContentType.guess (uri, null, out uncertain);
            if (!uncertain)
                info = AppInfo.get_default_for_type (type, true);

            if (info == null) {
                var file = File.new_for_uri (uri);

                try {
                    var finfo = file.query_info (FileAttribute.STANDARD_CONTENT_TYPE,
                                                 FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);

                    if (finfo.has_attribute (FileAttribute.STANDARD_CONTENT_TYPE)) {
                        info = AppInfo.get_default_for_type (finfo.get_attribute_string (FileAttribute.STANDARD_CONTENT_TYPE), true);
                    }
                } catch (Error e) {
                    warning ("Could not get file info %s", e.message);
                }
            }
        }

        return info;
    }

    public void get_current_selection_link_or_pwd (Fermion.TerminalWidget term, SelectionCallback cb) {
        var link_uri = term.link_uri;
        if (link_uri == null) {
            if (term.get_has_selection ()) {
                cb (term.get_text_selected ());
            } else {
                cb (term.get_shell_location ());
            }
        } else {
            if (!link_uri.contains ("://")) {
                // TODO https?
                // Or maybe a security option?
                var new_link_uri = @"http://$(link_uri)";

                cb (new_link_uri);
            } else {
                cb (link_uri);
            }
        }
    }

    public string? sanitize_path (string _path, string shell_location) {
        /* Remove trailing whitespace, ensure scheme, substitute leading "~" and "..", remove extraneous "/" */
        string scheme, path;

        var parts_scheme = _path.split ("://", 2);
        if (parts_scheme.length == 2) {
            scheme = parts_scheme[0] + "://";
            path = parts_scheme[1];
        } else {
            scheme = "file://";
            path = _path;
        }

        path = Uri.unescape_string (path);
        if (path == null) {
            return null;
        }

        path = strip_uri (path);

        do {
            path = path.replace ("//", "/");

        } while (path.contains ("//"));

        var parts_sep = path.split (Path.DIR_SEPARATOR_S, 3);
        var index = 0;
        while (parts_sep[index] == null && index < parts_sep.length - 1) {
            index++;
        }

        if (parts_sep[index] == "~") {
            parts_sep[index] = Environment.get_home_dir ();
        } else if (parts_sep[index] == ".") {
            parts_sep[index] = shell_location;
        } else if (parts_sep[index] == "..") {
            parts_sep[index] = construct_parent_path (shell_location);
        }

        var result = escape_uri (scheme + string.joinv (Path.DIR_SEPARATOR_S, parts_sep).replace ("//", "/"));
        return result;
    }

    private string construct_parent_path (string path) {
        if (path.length < 2) {
            return Path.DIR_SEPARATOR_S;
        }

        var sb = new StringBuilder (path);

        if (path.has_suffix (Path.DIR_SEPARATOR_S)) {
            sb.erase (sb.str.length - 1, -1);
        }

        int last_separator = sb.str.last_index_of (Path.DIR_SEPARATOR_S);
        if (last_separator < 0) {
            last_separator = 0;
        }
        sb.erase (last_separator, -1);

        string parent_path = sb.str + Path.DIR_SEPARATOR_S;

        return parent_path;
    }

    private string? strip_uri (string? _uri) {
        string uri = _uri;
        /* Strip off any trailing spaces, newlines or carriage returns */
        if (_uri != null) {
            uri = uri.strip ();
            uri = uri.replace ("\n", "");
            uri = uri.replace ("\r", "");
        }

        return uri;
    }

    private string? escape_uri (string uri, bool allow_utf8 = true, bool allow_single_quote = true) {
        string rc = (Uri.RESERVED_CHARS_GENERIC_DELIMITERS +
                     Uri.RESERVED_CHARS_SUBCOMPONENT_DELIMITERS).replace ("#", "").replace ("*", "").replace ("~", "");

        if (!allow_single_quote) {
            rc = rc.replace ("'", "");
        }

        return Uri.escape_string ((Uri.unescape_string (uri) ?? uri), rc , allow_utf8);
    }


    // Adapted from GNOME Builder, will be removed once VTE is better
    public string get_pattern_at_coords (Fermion.TerminalWidget term,
                                       double x,
                                       double y) {
        var tag = 0;

        var cell_width = term.get_char_width ();
        var cell_height = term.get_char_height ();

        var column = x / cell_width;
        var row = y / cell_height;

        return term.match_check ((long) column, (long) row, out tag);
    }
}
