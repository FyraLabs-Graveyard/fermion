/* application.vala
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
    public class Application : He.Application {
        public static GLib.Settings settings;

        private List<Fermion.Window> windows = new List<Fermion.Window> ();

        public static string? working_directory = null;
        private static string[]? command_execute = null;
        private static string? command_multiline = null;

        private static bool option_help = false;
        private static bool option_version = false;
        private static bool option_new_window = false;

        private const GLib.ActionEntry app_entries[] = {
            { "new-window", on_new_window },
            { "about", on_about_action },
            { "preferences", on_preferences_action },
            { "quit", quit }
        };

        private const OptionEntry[] ENTRIES = {
            { "version", 'v', 0, OptionArg.NONE, ref option_version, N_("Show version"), null },
            /* -e flag is used for running single string commands. May be more than one -e flag in cmdline */
            { "execute", 'e', 0, OptionArg.STRING_ARRAY, ref command_execute, N_("Run a program in terminal"), "COMMAND" },
            /* -x flag is removed before OptionContext parser applied but is included here so that it appears in response
             *  to  the --help flag */
            { "commandline", 'x', 0, OptionArg.STRING, ref command_multiline,
              N_("Run remainder of line as a command in terminal. Can also use '--' as flag"), "COMMAND_LINE" },
            { "new-window", 'n', 0, OptionArg.NONE, ref option_new_window,
              N_("Open a new terminal window"), null },
            { "help", 'h', 0, OptionArg.NONE, ref option_help, N_("Show help"), null },
            { "working-directory", 'w', 0, OptionArg.FILENAME, ref working_directory,
              N_("Set shell working directory"), "DIR" },
    
            { null }
        };

        public Application () {
            Object (
                flags: ApplicationFlags.HANDLES_COMMAND_LINE,
                application_id: Config.APP_ID,
                resource_base_path: "/co/tauos/Fermion"
            );

            settings = new GLib.Settings (Config.APP_SETTINGS);
            Intl.setlocale (LocaleCategory.ALL, "");
            Intl.textdomain (Config.GETTEXT_PACKAGE);
            Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
            Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
            
            add_action_entries (app_entries, this);
            set_accels_for_action ("app.quit", {"<primary>q"});
            set_accels_for_action ("app.new-window", {"<Control><Shift>n"});
        }

        protected override void startup () {
            Gdk.RGBA accent_color = { 0 };
            accent_color.parse("#bf56a8");
            default_accent_color = He.Color.from_gdk_rgba(accent_color);

            base.startup ();
        }

        public void new_window () {
            var win = new Window (this, null, null);
            win.present ();
        }

        /*
         * GObject Overrides
         */
        public override void window_added (Gtk.Window window) {
            windows.append (window as Fermion.Window);
            base.window_added (window);
        }

        public override void window_removed (Gtk.Window window) {
            windows.remove (window as Fermion.Window);
            base.window_removed (window);
        }

        public override int command_line (ApplicationCommandLine command_line) {
            hold ();
            int res = handle_command_line (command_line);
            release ();
            return res;
        }

        private Fermion.Window? get_last_window () {
            uint length = windows.length ();

            return length > 0 ? windows.nth_data (length - 1) : null;
        }

        private int handle_command_line (ApplicationCommandLine command_line) {
            var context = new OptionContext (null);
            context.add_main_entries (ENTRIES, "co.tauos.Fermion");
            context.set_help_enabled (false);

            string[] args = command_line.get_arguments ();
            string commandline = "";
            string[] arg_opt = {};
            string[] arg_cmd = {};
            bool build_cmdline = false;

             /* Everything after "--" or "-x" or "--commandline=" is to be treated as a single command to be executed
              * (maybe with its own options) so it is not passed to the parser.
              */
            foreach (unowned string s in args) {
                if (build_cmdline) {
                    arg_cmd += s;
                } else {
                    if (s == "--" || s == "-x" || s.has_prefix ("--commandline=")) {
                        if (s.has_prefix ("--commandline=") && s.length > 14) {
                            arg_cmd += s.substring (14);
                        }

                        build_cmdline = true;
                    } else {
                        arg_opt += s;
                    }
                }
            }

            commandline = string.joinv (" ", arg_cmd);

            try {
                unowned string[] tmp = arg_opt;
                context.parse (ref tmp);
            } catch (Error e) {
                stdout.printf ("co.tauos.Fermion: ERROR: " + e.message + "\n");
                return 0;
            }

            if (option_help) {
                command_line.print (context.get_help (true, null));
            } else if (option_version) {
                command_line.print ("%s %s", "Fermion" + Config.NAME_SUFFIX, Config.VERSION);
            } else {
                if (command_execute != null) {
                    // TODO this would generate multiple command tabs lol
                    print ("This command is not yet programmed lol");
                } else if (commandline.length > 0) {
                    run_command_line (commandline, working_directory);
                } else {
                    start_terminal_with_working_directory (working_directory);
                }
            }

            return 0;
        }

        private void run_command_line (string command_line, string? working_directory = null) {
            Fermion.Window? window = get_last_window ();

            if (window == null || option_new_window) {
                window = new Window (this, command_line, working_directory);
            } else {
                window.new_tab (working_directory, command_line);
            }
            window.present ();
        }

        private void start_terminal_with_working_directory (string? working_directory) {
            Fermion.Window? window = get_last_window ();

            if (window == null || option_new_window) {
                window = new Window.with_working_directory (this, working_directory);
            } else {
                window.new_tab (working_directory);
            }
            window.present ();
        }

        private void on_about_action () {
            string[] developers = { "Jamie Murphy", "Lains" };
            new He.AboutWindow (
                this.active_window,
                @"Fermion $(Config.NAME_SUFFIX)",
                Config.APP_ID,
                Config.VERSION,
                Config.APP_ID, // Version
                "https://github.com/tau-OS/fermion/tree/main/po",
                "https://github.com/tau-OS/fermion/issues",
                "https://github.com/tau-OS/fermion",
                {},
                developers,
                2022,
                He.AboutWindow.Licenses.GPLv3,
                He.Colors.PINK
            ).present ();
        }

        private void on_preferences_action () {
            new Fermion.Preferences (this.active_window);
        }

        private void on_new_window () {
            new_window ();
        }
    }
}

public static int main (string[] args) {
    var app = new Fermion.Application ();
    return app.run (args);
}
