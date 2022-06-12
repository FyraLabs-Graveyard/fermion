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

namespace Terminal {
    [GtkTemplate (ui = "/co/tauos/Terminal/window.ui")]
    public class Window : He.ApplicationWindow {       
        [GtkChild]
        private unowned Gtk.Box box;

        public Terminal.Application app { get; construct; }
        public Gdk.Clipboard clipboard;
        public SimpleActionGroup actions { get; construct; }
        public TerminalWidget terminal { get; set; }

        // Keyboard Actions
        public const string ACTION_COPY = "action-copy";
        public const string ACTION_PASTE = "action-paste";
        private static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();

        private const ActionEntry[] ENTRIES = {
            { ACTION_COPY, action_copy_handler },
            { ACTION_PASTE, action_paste_handler }
        };
        
        public Window (Terminal.Application app, string? command, string? working_directory = GLib.Environment.get_current_dir ()) {
            Object (app: app);

            terminal = new TerminalWidget ();
            terminal.set_active_shell (working_directory);
            box.append (terminal);
            if (command != null) {
                terminal.run_program (command, working_directory);
            }
        }

        public Window.with_working_directory (Terminal.Application app, string? location = GLib.Environment.get_current_dir ()) {
            Object (app: app);

            terminal = new TerminalWidget ();
            terminal.set_active_shell (location);
            box.append (terminal);
        }

        static construct {
            action_accelerators[ACTION_COPY] = "<Control><Shift>c";
            action_accelerators[ACTION_PASTE] = "<Control><Shift>v";
        }

        construct {
            set_application (app);

            actions = new SimpleActionGroup ();
            actions.add_action_entries (ENTRIES, this);
            insert_action_group ("win", actions);

            foreach (var action in action_accelerators.get_keys ()) {
                var accels_array = action_accelerators[action].to_array ();
                accels_array += null;

                application.set_accels_for_action (@"win.$(action)", accels_array);
            }

            clipboard = this.get_clipboard ();
        }
    }
}
