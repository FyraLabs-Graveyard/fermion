/**
 * A modal window that accepts ContentLists or PreferencePages
 */
public class He.PreferenceWindow : He.Window, Gtk.Buildable {
    private Gtk.Box box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
    private Gtk.Stack stack = new Gtk.Stack ();
    private He.AppBar appbar = new He.AppBar ();
    private He.ViewSwitcher switcher = new He.ViewSwitcher ();
    private He.ViewTitle viewtitle = new He.ViewTitle ();

    /**
     * Add ContentList or PreferencePage children to this window
     */
    public void add_child (Gtk.Builder builder, GLib.Object child, string? type) {
        if (child.get_type () == typeof (He.ContentList)) {
            add_list (child as He.ContentList);
        } else if (child.get_type () == typeof (He.PreferencePage)) {
            add_page (child as He.PreferencePage);
        } else {
            warning (@"Child of type $(child.get_type ().to_string ()) is not supported.");
            ((He.Window) this).add_child (builder, child, type);
        }
    }

    /**
     * Add a Preference Page to this window
     */
    public void add_page (He.PreferencePage page) {
        if (page.title == null) {
            page.title = @"Page $(stack.pages.get_n_items () + 1)";
        }
        stack.add_titled (page as Gtk.Widget, page.title, page.title);
    }

    /**
     * Add a Content List to this window
     */
    public void add_list (He.ContentList list) {
        if (list.title == null || list.title == "") {
            list.title = @"Page $(stack.pages.get_n_items () + 1)";
        }
        var page = new He.PreferencePage (list.title);
        page.add_list (list);
        add_page (page);
    }

    /**
     * Create a new Preferences Window.
     */
    public PreferenceWindow (Gtk.Window? parent) {
        this.parent = parent;
    }

    construct {
        this.stack.pages.items_changed.connect (on_pages_changed);

        viewtitle.label = "Settings";

        appbar.show_buttons = true;
        appbar.flat = true;
        appbar.show_back = false;
        appbar.hexpand = true;

        switcher.stack = stack;
        switcher.set_margin_start (12);
        switcher.set_margin_end (12);
        stack.set_margin_start (12);
        stack.set_margin_end (12);

        box.append (appbar);
        box.append (switcher);
        box.append (stack);

        this.set_child (box);

        this.set_size_request (360, 400);
        this.set_default_size (360, 400);
        this.has_title = false;
        this.set_focusable (true);

        this.set_modal (true);

        on_pages_changed (0, 0, this.stack.pages.get_n_items ());
    }

    ~PreferenceWindow () {
        this.unparent ();
    }

    private void on_pages_changed (uint position, uint removed, uint added) {
        if (this.stack.pages.get_n_items () <= 1) {
            if (this.switcher.get_parent () != null && this.switcher.get_parent () == this.box) {
                this.box.remove (switcher);
                this.box.insert_child_after (viewtitle, appbar);
            } else if (this.viewtitle.get_parent () == null) {
                this.box.insert_child_after (viewtitle, appbar);
            } else {
                // Everything has been added
                return;
            }
        } else {
            if (this.viewtitle.get_parent () != null && this.viewtitle.get_parent () == this.box) {
                this.box.remove (viewtitle);
                this.box.insert_child_after (switcher, appbar);
            } else if (this.switcher.get_parent () == null) {
                this.box.insert_child_after (switcher, appbar);
            } else {
                // Everything has been added
                return;
            }
        }
    }
}
