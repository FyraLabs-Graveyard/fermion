/**
 * Standard tab designed for TabSwitcher
 */
public class He.Tab : He.Bin {
    Gtk.Label _label;
    public string label {
        get { return _label.label; }
        set {
            _label.label = value;
            _label.set_tooltip_text (value);
        }
    }

    public string tooltip {
        set {
            _label.set_tooltip_text (value);
        }
    }

    internal TabPage page_container;
    public Gtk.Widget page {
        get {
            return page_container.get_first_child ();
        }
        set {
            weak Gtk.Widget container_child = page_container.get_first_child ();
            if (container_child != null) {
                container_child.unparent ();
            }

            value.set_parent (page_container);
        }
    }

    He.TabSwitcher tab_switcher {
        get { return (get_parent () as Gtk.Notebook)?.get_parent () as He.TabSwitcher; }
    }

    public Pango.EllipsizeMode ellipsize_mode {
        get { return _label.ellipsize; }
        set { _label.ellipsize = value; }
    }

    /**
     * Create a new Tab
     */
    public Tab (string? label = null, Gtk.Widget? page = null) {
        Object (
            label: label
        );

        if (page != null) {
            this.page = page;
        }
    }

    internal signal void closed ();
    internal signal void close_others ();
    internal signal void close_others_right ();
    internal signal void new_window ();
    internal signal void duplicate ();
    internal signal void pin_switch ();

    private Gtk.Grid tab_layout;

    construct {
        _label = new Gtk.Label (null);
        _label.hexpand = true;
        _label.tooltip_text = label;
        _label.ellipsize = Pango.EllipsizeMode.END;

        tab_layout = new Gtk.Grid ();
        tab_layout.hexpand = false;
        tab_layout.orientation = Gtk.Orientation.HORIZONTAL;
        tab_layout.attach (_label, 0, 0);
        
        tab_layout.set_parent (this);

        page_container = new TabPage (this);
    }

    static construct {
        set_layout_manager_type (typeof (Gtk.BoxLayout));
    }

    ~Tab () {
        tab_layout.unparent ();
    }
}
