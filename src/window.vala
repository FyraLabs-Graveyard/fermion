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
    [GtkTemplate (ui = "/co/tauos/Fermion/window.ui")]
    public class Window : He.ApplicationWindow {       
        [GtkChild] private unowned He.TabSwitcher switcher;

        public Fermion.Application app { get; construct; }
        public Gdk.Clipboard clipboard;
        public SimpleActionGroup actions { get; construct; }
        public Menu menu = new GLib.Menu ();

        private Gtk.PopoverMenu popover { get; set; }

        public GLib.List <TerminalWidget> terminals = new GLib.List <TerminalWidget> ();

        // Keyboard Actions
        public const string ACTION_COPY = "action-copy";
        public const string ACTION_PASTE = "action-paste";
        public const string ACTION_SELECT_ALL = "action-select-all";
        public const string ACTION_DUPLICATE_TAB = "action-duplicate-tab";
        private static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

        private const ActionEntry[] ENTRIES = {
            { ACTION_COPY, action_copy },
            { ACTION_PASTE, action_paste },
            { ACTION_SELECT_ALL, action_select_all },
            { ACTION_DUPLICATE_TAB, action_duplicate_tab },
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

        static construct {
            // this is broken and idk why
            action_accelerators[ACTION_COPY] = "<Control><Shift>c";
            action_accelerators[ACTION_PASTE] = "<Ctrl><Shft>V";
            action_accelerators[ACTION_SELECT_ALL] = "<Control><Shift>a";
            action_accelerators[ACTION_DUPLICATE_TAB] = "<Control><Shift>d";
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

            menu.append ("Copy", "win.action-copy");
            menu.append ("Paste", "win.action-paste");
            menu.append ("Select All", "win.action-select-all");

            popover.set_menu_model (menu);
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
                on_destroy ();
            } else {
                terminals.remove (widget);
            }
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
            // TODO maybe threadservice
            Idle.add (() => {
                get_term_widget (new_tab).grab_focus ();
                popover.unparent ();
                popover.set_parent (new_tab.page as TerminalWidget);
                return false;
            });
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

        private TerminalWidget new_tab (string? dir, string? program = null) {
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

            handle_events (widget);

            return widget;
        }

        private He.Tab create_tab (string label, TerminalWidget term) {
            var tab = new He.Tab (label, term);
            term.tab = tab;
            tab.tooltip = term.current_working_directory;

            return tab;
        }

        private void on_destroy () {
            foreach (unowned TerminalWidget terminal in terminals) {
                terminal.end_process ();
            }
            this.destroy ();
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
        private void action_duplicate_tab () {
            new_tab ((switcher.current.page as TerminalWidget)?.get_shell_location ());
        }
    }
}
