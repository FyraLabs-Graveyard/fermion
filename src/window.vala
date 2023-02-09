/* window.vala
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
    [GtkTemplate (ui = "/com/fyralabs/Fermion/window.ui")]
    public class Window : He.ApplicationWindow {       
        [GtkChild] private unowned He.TabSwitcher switcher;

        public Fermion.Application app { get; construct; }
        public Gdk.Clipboard clipboard;
        public SimpleActionGroup actions { get; construct; }
        public Menu menu = new GLib.Menu ();

        private Gtk.PopoverMenu popover { get; set; }
        private bool should_close = false;

        public TerminalWidget current_terminal { get; private set; default = null; }
        public GLib.List <TerminalWidget> terminals = new GLib.List <TerminalWidget> ();

        // Keyboard Actions
        public const string ACTION_COPY = "action-copy";
        public const string ACTION_PASTE = "action-paste";
        public const string ACTION_SELECT_ALL = "action-select-all";
        public const string ACTION_NEW_TAB = "action-new-tab";
        public const string ACTION_DUPLICATE_TAB = "action-duplicate-tab";
        public const string ACTION_RELOAD_TAB = "action-reload-tab";
        public const string ACTION_CLOSE_TAB = "action-close-tab";

        // Other Events
        public const string ACTION_OPEN_IN_BROWSER = "action-open-in-browser";
        public const string ACTION_FULLSCREEN = "action-fullscreen";
        public const string ACTION_ZOOM_DEFAULT = "action-zoom-default";
        public const string ACTION_ZOOM_IN = "action-zoom-in";
        public const string ACTION_ZOOM_OUT = "action-zoom-out";
        private static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

        private const ActionEntry[] ENTRIES = {
            { ACTION_COPY, action_copy },
            { ACTION_PASTE, action_paste },
            { ACTION_SELECT_ALL, action_select_all },
            { ACTION_NEW_TAB, action_new_tab },
            { ACTION_DUPLICATE_TAB, action_duplicate_tab },
            { ACTION_RELOAD_TAB, action_reload_tab },
            { ACTION_CLOSE_TAB, action_close_tab },

            { ACTION_OPEN_IN_BROWSER, action_open_in_browser},
            { ACTION_FULLSCREEN, action_fullscreen },
            { ACTION_ZOOM_DEFAULT, action_zoom_default },
            { ACTION_ZOOM_IN, action_zoom_in },
            { ACTION_ZOOM_OUT, action_zoom_out },
        };

        private TerminalWidget get_term_widget (He.Tab tab) {
            return (TerminalWidget)tab.page;
        }
        
        public Window (Fermion.Application app, string? command, string? working_directory = GLib.Environment.get_current_dir ()) {
            Object (app: app);

            new_tab (working_directory);
            if (command != null) {
                new_tab (working_directory, command);
            }
        }

        public Window.with_working_directory (Fermion.Application app, string? location = GLib.Environment.get_current_dir ()) {
            Object (app: app);

            new_tab (location);
        }

        public Window.blank (Fermion.Application app) {
            Object (app: app);
        }

        static construct {
            action_accelerators[ACTION_COPY] = "<Control><Shift>c";
            action_accelerators[ACTION_PASTE] = "<Control><Shift>V";
            action_accelerators[ACTION_SELECT_ALL] = "<Control><Shift>a";
            action_accelerators[ACTION_NEW_TAB] = "<Control><Shift>t";
            action_accelerators[ACTION_DUPLICATE_TAB] = "<Control><Shift>d";
            action_accelerators[ACTION_RELOAD_TAB] = "<Shift>F5";
            action_accelerators[ACTION_RELOAD_TAB] = "<Control><Shift>r";
            action_accelerators[ACTION_CLOSE_TAB] = "<Control><Shift>w";

            action_accelerators[ACTION_FULLSCREEN] = "F11";
            action_accelerators[ACTION_ZOOM_DEFAULT] = "<Control>0";
            action_accelerators[ACTION_ZOOM_DEFAULT] = "<Control>KP_0";
            action_accelerators[ACTION_ZOOM_IN] = "<Control>plus";
            action_accelerators[ACTION_ZOOM_IN] = "<Control>equal";
            action_accelerators[ACTION_ZOOM_OUT] = "<Control>minus";
        }

        construct {
            set_application (app);

            popover = new Gtk.PopoverMenu.from_model (menu);
            actions = new SimpleActionGroup ();
            actions.add_action_entries (ENTRIES, this);
            insert_action_group ("win", actions);

            foreach (var action in action_accelerators.get_keys ()) {
                var accels_array = action_accelerators[action].to_array ();

                application.set_accels_for_action (@"win.$(action)", accels_array);
            }

            clipboard = this.get_clipboard ();

            var ms1 = new Menu ();
            var s1 = new MenuItem.section (null, ms1);
            var ms2 = new Menu ();
            ms2.append ("Copy", "win.action-copy");
            ms2.append ("Paste", "win.action-paste");
            ms2.append ("Select All", "win.action-select-all");
            var s2 = new MenuItem.section (null, ms1);

            menu.append_section (null, ms1);
            menu.append_section (null, ms2);

            popover.set_menu_model (menu);
        }

        protected override bool close_request () {
            debug ("Exiting window... Disposing of stuff...");
            foreach (unowned TerminalWidget terminal in terminals) {
                terminal.end_process ();
            }
            this.dispose ();
            return true;
        }

        private void update_browser_label (string? uri) {
            AppInfo? info = Fermion.Utils.get_default_app_for_uri (uri);

            if (!info.get_display_name ().contains("Fermion")) {
                menu.remove (0);
                var ms1 = new Menu ();
                var app = info != null ? info.get_display_name () : "Default app";
                ms1.append (@"Show in $(app)", "win.action-open-in-browser");
                menu.insert_section (0, null, ms1);
            } else {
                menu.remove (0);
            }
        }

        [GtkCallback]
        private void on_tab_added (He.Tab tab) {
            var widget = get_term_widget (tab);
            terminals.append (widget);
        }

        [GtkCallback]
        private void on_tab_removed (He.Tab tab) {
            var widget = get_term_widget (tab);
            if (switcher.n_tabs == 0) {
                foreach (unowned TerminalWidget terminal in terminals) {
                    terminal.end_process ();
                }
                this.dispose ();
            } else {
                terminals.remove (widget);
            }
        }

        [GtkCallback]
        private void on_tab_moved (He.Tab tab) {
            var widget = get_term_widget (tab);
            var win = new Window.blank (app);
            
            switcher.remove_tab (tab);
            win.switcher.insert_tab (tab, -1);
            win.current_terminal = widget;
            win.present ();
        }

        [GtkCallback]
        private void on_tab_duplicated (He.Tab tab) {
            var widget = get_term_widget (tab);
            new_tab (widget.get_shell_location ());
        }

        [GtkCallback]
        private void on_new_tab_requested () {
            new_tab (Environment.get_home_dir ());
        }

        [GtkCallback]
        private void on_tab_switched (He.Tab? old_tab, He.Tab new_tab) {
            current_terminal = get_term_widget (new_tab);

            Idle.add (() => {
                get_term_widget (new_tab).grab_focus ();
                popover.unparent ();
                popover.set_parent (new_tab.page as TerminalWidget);
                return false;
            });
        }

        [GtkCallback]
        private bool on_close_tab_requested (He.Tab tab) {
            var widget = get_term_widget (tab);

            if (should_close) {
                widget.kill_fg ();

                current_terminal.grab_focus ();
                
                should_close = false;

                return true;
            }

            if (widget.try_get_foreground_pid (null)) {
                var dialog = new ProcessWarningDialog (
                    this,
                    ProcessWarnType.TAB_CLOSE
                );
                dialog.present ();

                dialog.returned.connect (() => {
                    should_close = true;
                    
                    tab.actions.activate_action ("action-close", null);

                    dialog.destroy ();
                });

                return false;
            }

            return true;
        }

        private void handle_events (TerminalWidget terminal) {
            Gtk.EventControllerKey controller = new Gtk.EventControllerKey ();
            Gtk.GestureClick rightclick = new Gtk.GestureClick () {
                button = Gdk.BUTTON_SECONDARY
            };
            terminal.add_controller (rightclick);
            terminal.add_controller (controller);
            popover.unparent ();
            popover.set_parent (terminal);

            rightclick.pressed.connect ((n_press, x, y) => {
                terminal.get_link_uri (x, y);
                Fermion.Utils.get_current_selection_link_or_pwd (terminal, (uri) => {
                    update_browser_label (Fermion.Utils.sanitize_path (uri, current_terminal.get_shell_location ()));
                });

                Gdk.Rectangle rect = {(int)x,
                                      (int)y,
                                      0,
                                      0};
                popover.set_pointing_to (rect);
                popover.popup ();
            });

            controller.key_pressed.connect ((keyval, keycode, state) => {
                switch (keyval) {
                    case Gdk.Key.Menu:
                        long col, row;
                        terminal.get_cursor_position (out col, out row);
                        var cell_width = terminal.get_char_width ();
                        var cell_height = terminal.get_char_height ();
                        var vadj_val = terminal.get_vadjustment ().get_value ();

                        Gdk.Rectangle rect = {(int)(col * cell_width),
                                            (int)((row - vadj_val) * cell_height),
                                            (int)cell_width,
                                            (int)cell_height};

                        popover.set_pointing_to (rect);
                        popover.popup ();
                        break;
                    default:
                        break;
                }

                return false;
            });

            terminal.grab_focus ();
        }

        public TerminalWidget new_tab (string? dir, string? program = null) {
            var widget = new TerminalWidget ();

            var tab = create_tab (
                dir != null ? Path.get_basename (dir) : TerminalWidget.DEFAULT_LABEL,
                widget
            );

            switcher.insert_tab (tab, -1);

            widget.grab_focus ();
            switcher.current = tab;

            if (program == null) {
                if (dir == "" || dir == null) {
                    widget.set_active_shell ();
                } else {
                    widget.set_active_shell (dir);
                }
            } else {
                widget.run_program (program, dir);
            }

            widget.child_exited.connect (() => {
                if (!widget.killed) {
                    if (program != null) {
                        program = null;
                    } else {
                        //widget.tab.close ();
                        return;
                    }
                }
            });

            handle_events (widget);

            return widget;
        }

        private He.Tab create_tab (string label, TerminalWidget term) {
            var tab = new He.Tab (label, term);
            term.tab = tab;
            tab.tooltip = term.current_working_directory;

            return tab;
        }

        private void action_copy () {
            action_copy_handler (switcher.current.page as TerminalWidget);
        }

        private void action_paste () {
            action_paste_handler (switcher.current.page as TerminalWidget);
        }

        private void action_select_all () {
            action_select_all_handler (switcher.current.page as TerminalWidget);
        }

        private void action_new_tab () {
            new_tab (Environment.get_home_dir ());
        }

        private void action_duplicate_tab () {
            new_tab (current_terminal.get_shell_location ());
        }

        private void action_reload_tab () {
            current_terminal.reload ();
        }

        private void action_close_tab () {
            current_terminal.grab_focus ();
        }

        private void action_open_in_browser () {
            action_browser_handler (switcher.current.page as TerminalWidget);
        }

        private void action_fullscreen () {
            if (fullscreened) {
                unfullscreen ();
            } else {
                fullscreen ();
            }
        }

        private void action_zoom_default () {
            current_terminal.set_font_scale (1.0);
        }

        private const double MIN_SCALE = 0.25;
        private const double MAX_SCALE = 4.0;
        private void action_zoom_in () {
            var scale = (current_terminal.font_scale + 0.1).clamp (MIN_SCALE, MAX_SCALE);
            current_terminal.set_font_scale (scale);
        }
        private void action_zoom_out () {
            var scale = (current_terminal.font_scale - 0.1).clamp (MIN_SCALE, MAX_SCALE);
            current_terminal.set_font_scale (scale);
        }
    }
}
