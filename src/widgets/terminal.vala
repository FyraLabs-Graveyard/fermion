/* widgets/terminal.vala
 *
 * Copyright 2022 Fyra Labs
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Fermion {
    public class TerminalWidget : Vte.Terminal {    
        GLib.Pid child_pid;

        internal const string DEFAULT_LABEL = "Terminal";
        public string current_working_directory { get; private set; default = "";}

        // URL Matching. Yes, GNOME Terminal does this too.
        const string USERCHARS = "-[:alnum:]";
        const string USERCHARS_CLASS = "[" + USERCHARS + "]";
        const string PASSCHARS_CLASS = "[-[:alnum:]\\Q,?;.:/!%$^*&~\"#'\\E]";
        const string HOSTCHARS_CLASS = "[-[:alnum:]]";
        const string HOST = HOSTCHARS_CLASS + "+(\\." + HOSTCHARS_CLASS + "+)*";
        const string PORT = "(?:\\:[[:digit:]]{1,5})?";
        const string PATHCHARS_CLASS = "[-[:alnum:]\\Q_$.+!*,;:@&=?/~#%\\E]";
        const string PATHTERM_CLASS = "[^\\Q]'.}>) \t\r\n,\"\\E]";
        const string SCHEME = "(?:news:|telnet:|nntp:|file:\\/|https?:|ftps?:|sftp:|webcal:" +
                              "|irc:|sftp:|ldaps?:|nfs:|smb:|rsync:|ssh:|rlogin:|telnet:|git:" +
                              "|git\\+ssh:|bzr:|bzr\\+ssh:|svn:|svn\\+ssh:|hg:|mailto:|magnet:)";

        const string USERPASS = USERCHARS_CLASS + "+(?:" + PASSCHARS_CLASS + "+)?";
        const string URLPATH = "(?:(/" + PATHCHARS_CLASS +
                               "+(?:[(]" + PATHCHARS_CLASS +
                               "*[)])*" + PATHCHARS_CLASS +
                               "*)*" + PATHTERM_CLASS +
                               ")?";

        const string[] REGEX_STRINGS = {
            SCHEME + "//(?:" + USERPASS + "\\@)?" + HOST + PORT + URLPATH,
            "(?:www|ftp)" + HOSTCHARS_CLASS + "*\\." + HOST + PORT + URLPATH,
            "(?:callto:|h323:|sip:)" + USERCHARS_CLASS + "[" + USERCHARS + ".]*(?:" + PORT + "/[a-z0-9]+)?\\@" + HOST,
            "(?:mailto:)?" + USERCHARS_CLASS + "[" + USERCHARS + ".]*\\@" + HOSTCHARS_CLASS + "+\\." + HOST,
            "(?:news:|man:|info:)[[:alnum:]\\Q^_{|}~!\"#$%&'()*+,./;:=?`\\E]+"
        };

        public He.Tab tab;
        private string _tab_label;
        public string tab_label {
            get {
                return _tab_label;
            }

            set {
                if (value != null) {
                    _tab_label = value;
                    tab.label = tab_label;
                }
            }
        }

        public TerminalWidget () {
            this.set_hexpand (true);
            this.set_vexpand (true);

            this.clickable (REGEX_STRINGS);

            restore_settings ();
            Application.settings.changed.connect (restore_settings);
        }

        public void restore_settings () {
            Gdk.RGBA background_color = Gdk.RGBA ();
            background_color.parse (Application.settings.get_string ("background-color"));
            Gdk.RGBA foreground_color = Gdk.RGBA ();
            foreground_color.parse (Application.settings.get_string ("foreground-color"));

            this.set_colors (foreground_color, background_color, null);

            Gdk.RGBA cursor_color = Gdk.RGBA ();
            cursor_color.parse (Application.settings.get_string ("cursor-color"));

            this.set_color_cursor (cursor_color);

            this.set_cursor_shape ((Vte.CursorShape) Application.settings.get_enum ("cursor-shape"));

            this.set_audible_bell (Application.settings.get_boolean ("audible-bell"));
        }

        public void run_program (string program_string, string? working_directory) {
            try {
                string[]? program_with_args = null;
                Shell.parse_argv (program_string, out program_with_args);
    
                this.spawn_async (Vte.PtyFlags.DEFAULT, working_directory, program_with_args, null, SpawnFlags.SEARCH_PATH, null, -1, null, terminal_callback);
            } catch (Error e) {
                warning (e.message);
                feed ((e.message + "\r\n\r\n").data);
                set_active_shell (working_directory);
            }
        }

        private void terminal_callback (Vte.Terminal terminal, GLib.Pid pid, Error? error) {
            if (pid != -1) {
                child_pid = pid;
            } else {
                feed ((error.message + "\r\n\r\n").data);
            }
        }

        public void set_active_shell (string? dir = GLib.Environment.get_current_dir ()) {
            string shell = Vte.get_user_shell ();
            string?[] envv = null;

            envv = {
                // Set environment variables
            };

            this.spawn_async (Vte.PtyFlags.DEFAULT, dir, { shell }, envv, SpawnFlags.SEARCH_PATH, null, -1, null, terminal_callback);
        }

        private void clickable (string[] str) {
            foreach (unowned string exp in str) {
                try {
                    var regex = new Vte.Regex.for_match (exp, -1, PCRE2.Flags.MULTILINE);
                    int id = this.match_add_regex (regex, 0);
                    this.match_set_cursor_name (id, "pointer");
                } catch (Error error) {
                    warning (error.message);
                }
            }
        }
    }
}
