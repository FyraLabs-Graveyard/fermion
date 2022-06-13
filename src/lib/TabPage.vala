/**
 * Auxilary Class
 */
public class He.TabPage : He.Bin {
    private unowned Tab _tab = null;

    public unowned Tab tab {
        get { return _tab; }
        set { _tab = value; }
    }

    He.TabSwitcher tab_switcher {
        get { return (get_parent () as Gtk.Notebook)?.get_parent () as He.TabSwitcher; }
    }

    /**
     * Create a new Tab
     */
    public TabPage (Tab tab) {
        Object (
            tab: tab
        );
    }

    static construct {
        set_layout_manager_type (typeof (Gtk.BoxLayout));
    }

    ~TabPage () {
        this.get_first_child ().unparent ();
    }
}
