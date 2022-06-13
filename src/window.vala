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
        [GtkChild]
        private unowned Gtk.Box box;

        public Fermion.Application app { get; construct; }
        public Gdk.Clipboard clipboard;
        public SimpleActionGroup actions { get; construct; }
        public Menu menu = new GLib.Menu ();
        public TerminalWidget terminal { get; set; }

        private Gtk.PopoverMenu popover { get; set; }

        // Keyboard Actions
        public const string ACTION_COPY = "action-copy";
        public const string ACTION_PASTE = "action-paste";
        public const string ACTION_SELECT_ALL = "action-select-all";
        private static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

        private const ActionEntry[] ENTRIES = {
            { ACTION_COPY, action_copy_handler },
            { ACTION_PASTE, action_paste_handler },
            { ACTION_SELECT_ALL, action_select_all_handler }
        };

        private void handle_events () {
            Gtk.EventControllerKey controller = new Gtk.EventControllerKey ();
            Gtk.GestureClick rightclick = new Gtk.GestureClick () {
                button = Gdk.BUTTON_SECONDARY
            };
            terminal.add_controller (rightclick);
            terminal.add_controller (controller);
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
        
        public Window (Fermion.Application app, string? command, string? working_directory = GLib.Environment.get_current_dir ()) {
            Object (app: app);

            terminal = new TerminalWidget ();
            terminal.set_active_shell (working_directory);
            box.append (terminal);
            if (command != null) {
                terminal.run_program (command, working_directory);
            }
            handle_events ();
        }

        public Window.with_working_directory (Fermion.Application app, string? location = GLib.Environment.get_current_dir ()) {
            Object (app: app);

            terminal = new TerminalWidget ();
            terminal.set_active_shell (location);
            box.append (terminal);
            handle_events ();
        }

        static construct {
            // this is broken and idk why
            action_accelerators[ACTION_COPY] = "<Control><Shift>c";
            action_accelerators[ACTION_PASTE] = "<Ctrl><Shft>V";
            action_accelerators[ACTION_SELECT_ALL] = "<Control><Shift>a";
        }

        construct {
            set_application (app);

            popover = new Gtk.PopoverMenu.from_model (menu);
            actions = new SimpleActionGroup ();
            actions.add_action_entries (ENTRIES, null);
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
    }
}
