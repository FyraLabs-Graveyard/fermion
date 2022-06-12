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

 namespace Terminal {
    public class Application : He.Application {
        public static GLib.Settings settings;

        public static string? working_directory = null;
        [CCode (array_length = false, array_null_terminated = true)]
        private static string[]? command_e = null;
        private static string? command_x = null;

        private static bool option_help = false;
        private static bool option_version = false;

        private const GLib.ActionEntry app_entries[] = {
            { "about", on_about_action },
            { "quit", quit }
        };

        private const OptionEntry[] ENTRIES = {
            { "version", 'v', 0, OptionArg.NONE, ref option_version, N_("Show version"), null },
            /* -e flag is used for running single string commands. May be more than one -e flag in cmdline */
            { "execute", 'e', 0, OptionArg.STRING_ARRAY, ref command_e, N_("Run a program in terminal"), "COMMAND" },
            /* -x flag is removed before OptionContext parser applied but is included here so that it appears in response
             *  to  the --help flag */
            { "commandline", 'x', 0, OptionArg.STRING, ref command_x,
              N_("Run remainder of line as a command in terminal. Can also use '--' as flag"), "COMMAND_LINE" },
            { "help", 'h', 0, OptionArg.NONE, ref option_help, N_("Show help"), null },
            { "working-directory", 'w', 0, OptionArg.FILENAME, ref working_directory,
              N_("Set shell working directory"), "DIR" },
    
            { null }
        };

        construct {
            settings = new GLib.Settings (Config.APP_SETTINGS);
            application_id = Config.APP_ID;
            flags |= ApplicationFlags.HANDLES_COMMAND_LINE;
            Intl.setlocale (LocaleCategory.ALL, "");
            Intl.textdomain (Config.GETTEXT_PACKAGE);
            Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
            Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
            
            add_action_entries (app_entries, this);
            set_accels_for_action ("app.quit", {"<primary>q"});
        }

        public override int command_line (ApplicationCommandLine command_line) {
            hold ();
            int res = _command_line (command_line);
            release ();
            return res;
        }

        private int _command_line (ApplicationCommandLine command_line) {
            var context = new OptionContext (null);
            context.add_main_entries (ENTRIES, "terminal");
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
                stdout.printf ("terminal: ERROR: " + e.message + "\n");
                return 0;
            }

            if (option_help) {
                command_line.print (context.get_help (true, null));
            } else if (option_version) {
                command_line.print ("%s %s", "Terminal" + Config.NAME_SUFFIX, Config.VERSION + "\n\n");
            } else {
                if (command_e != null) {
                    // TODO this would generate multiple command tabs lol
                    print ("This command is not yet programmed lol");
                } else if (commandline.length > 0) {
                    run_command_line (commandline, working_directory);
                } else if (command_x != null) {
                    const string WARNING = "Usage: --commandline=[COMMANDLINE] without spaces around '='\r\n\r\n";
                    print ("%s\n", WARNING);
                    start_terminal_with_working_directory (working_directory);
                } else {
                    start_terminal_with_working_directory (working_directory);
                }
            }

            return 0;
        }

        private void run_command_line (string command_line, string? working_directory = null) {
            var win = this.active_window;
            if (win == null) {
                win = new Window(this, command_line, working_directory);
            } else {
                print ("Terminal already started");
            }
            win.present ();
        }

        private void start_terminal_with_working_directory (string? working_directory) {
            var win = this.active_window;
            if (win == null) {
                win = new Window.with_working_directory (this, working_directory);
            } else {
                print ("Terminal already started");
            }
            win.present ();
        }

        private void on_about_action () {
            string[] authors = { "Jamie Murphy" };
            string[] artists = { "Jamie Murphy", "Lains https://github.com/lainsce" };
            Gtk.show_about_dialog (this.active_window,
                                   "program-name", "Terminal" + Config.NAME_SUFFIX,
                                   "authors", authors,
                                   "artists", artists,
                                   "comments", "Use the command line",
                                   "copyright", "Made with <3 by Fyra Labs",
                                   "logo-icon-name", Config.APP_ID,
                                   "website", "https://tauos.co",
                                   "website-label", "tauOS Website",
                                   "license-type", Gtk.License.GPL_3_0,
                                   "version", Config.VERSION);
        }
    }
}

public static int main (string[] args) {
    var app = new Terminal.Application ();
    return app.run (args);
}
