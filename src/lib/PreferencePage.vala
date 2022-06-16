/**
 * Auxilary Class for handling the contents of Preference Windows
 */
public class He.PreferencePage : He.Bin, Gtk.Buildable {
    private Gtk.Box box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

    /**
     * The title of this Preference Page. This is used to determine the name shown in the View Switcher.
     */
    public string title {
        get { return _name; }
        set { _name = value; }
    }
    private string _name = null;

    /**
     * Add a child to this page, should only be used in the context of a UI or Blueprint file.
     * There should be no need to use this method in code.
     */
    public override void add_child (Gtk.Builder builder, GLib.Object child, string? type) {
        box.append ((Gtk.Widget) child);
    }

    /**
     * Add a Content List to this page
     */
    public void add_list (He.ContentList list) {
        box.append (list);
    }
    
    /**
     * Create a new Preferences Page.
     */
    public PreferencePage (string title) {
        this.title = title;
    }

    static construct {
        set_layout_manager_type (typeof (Gtk.BoxLayout));
    }

    construct {
        box.set_parent (this);
    }

    ~PreferencePage () {
        this.unparent ();
    }
}
