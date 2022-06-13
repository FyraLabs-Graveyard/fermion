/**
 * Standard tab designed for TabSwitcher, used to form a tabbed UI
 */
public class He.Tab : He.Bin {
    /**
     * The label/title of the tab
     **/
    public string label {
        get { return _label.label; }
        set {
            _label.label = value;
            _label.set_tooltip_markup (value);
        }
    }
    Gtk.Label _label;

    /**
     * The Pango marked up text that will be shown in a tooltip when the tab is hovered.
     **/
    public string tooltip {
        set {
            _label.set_tooltip_markup (value);
        }
    }

    /**
     * The TabPage to hold children, to appear when this tab is active
     **/
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
    internal TabPage page_container;

    private bool _is_current_tab = false;
        internal bool is_current_tab {
            set {
                _is_current_tab = value;
                //  update_close_button_visibility ();
            }
        }

    He.TabSwitcher tab_switcher {
        get { return (get_parent () as Gtk.Notebook)?.get_parent () as He.TabSwitcher; }
    }

    private Gtk.CenterBox tab_layout;
    public Menu menu { get; set; }

    internal signal void closed ();
    internal signal void close_others ();
    internal signal void close_others_right ();

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

    construct {
        _label = new Gtk.Label (null);
        _label.hexpand = true;
        _label.tooltip_text = label;
        _label.ellipsize = Pango.EllipsizeMode.END;

        var close_button = new He.TintButton.from_icon ("list-add-symbolic");
        close_button.tooltip_text = "Close Tab";
        close_button.valign = Gtk.Align.CENTER;

        tab_layout = new Gtk.CenterBox ();
        tab_layout.hexpand = true;
        tab_layout.set_end_widget (close_button);
        tab_layout.set_center_widget (_label);

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
