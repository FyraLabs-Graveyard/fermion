/* widgets/terminal.vala
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
    public class TerminalWidget : Vte.Terminal {    
        GLib.Pid pid;

        internal const string DEFAULT_LABEL = "Terminal";
        public string current_working_directory { get; private set; default = "";}

        static string[] fenvv = {
            "TERM=xterm-256color",
            "COLORTERM=truecolor",
            "TERM_PROGRAM=%s".printf (Config.APP_ID),
        };

        // URL Matching. Yes, GNOME Terminal does this too.
        const string USERCHARS = "-[:alnum:]";
        const string USERCHARS_CLASS = "[" + USERCHARS + "]";
        const string PASSCHARS_CLASS = "[-[:alnum:]\\Q,?;.:/!%$^*&~\"#'\\E]";
        const string HOSTCHARS_CLASS = "[-[:alnum:]]";
        const string HOST = HOSTCHARS_CLASS + "+(\\." + HOSTCHARS_CLASS + "+)*";
        const string PORT = "(?:\\:[[:digit:]]{1,5})?";
        const string PATHCHARS_CLASS = "[-[:alnum:]\\Q_$.+!*,;:@&=?/~#%\\E]";
        const string PATHTERM_CLASS = "[^\\Q]'.}>) \t\r\n,\"\\E]";
        const string SCHEME = "(?:news:|telnet:|nntp:|file:\\/|https?:|ftps?:|sftp:|webcal:" +
                              "|irc:|sftp:|ldaps?:|nfs:|smb:|rsync:|ssh:|rlogin:|telnet:|git:" +
                              "|git\\+ssh:|bzr:|bzr\\+ssh:|svn:|svn\\+ssh:|hg:|mailto:|magnet:)";

        const string USERPASS = USERCHARS_CLASS + "+(?:" + PASSCHARS_CLASS + "+)?";
        const string URLPATH = "(?:(/" + PATHCHARS_CLASS +
                               "+(?:[(]" + PATHCHARS_CLASS +
                               "*[)])*" + PATHCHARS_CLASS +
                               "*)*" + PATHTERM_CLASS +
                               ")?";

        const string[] REGEX_STRINGS = {
            SCHEME + "//(?:" + USERPASS + "\\@)?" + HOST + PORT + URLPATH,
            "(?:www|ftp)" + HOSTCHARS_CLASS + "*\\." + HOST + PORT + URLPATH,
            "(?:callto:|h323:|sip:)" + USERCHARS_CLASS + "[" + USERCHARS + ".]*(?:" + PORT + "/[a-z0-9]+)?\\@" + HOST,
            "(?:mailto:)?" + USERCHARS_CLASS + "[" + USERCHARS + ".]*\\@" + HOSTCHARS_CLASS + "+\\." + HOST,
            "(?:news:|man:|info:)[[:alnum:]\\Q^_{|}~!\"#$%&'()*+,./;:=?`\\E]+"
        };

        public bool child_has_exited {
            get;
            private set;
        }

        public He.Tab tab;
        private string _tab_label;
        public string tab_label {
            get {
                return _tab_label;
            }

            set {
                if (value != null) {
                    _tab_label = value;
                    tab.label = tab_label;
                }
            }
        }

        public string link_uri;

        public bool try_get_foreground_pid (out int pid) {
            if (child_has_exited) {
                pid = -1;
                return false;
            }

            int pty = get_pty ().fd;
            int fgpid = Posix.tcgetpgrp (pty);

            if (fgpid != this.pid && fgpid != -1) {
                pid = (int) fgpid;
                return true;
            } else {
                pid = -1;
                return false;
            }
        }

        public TerminalWidget () {
            this.set_hexpand (true);
            this.set_vexpand (true);

            this.clickable (REGEX_STRINGS);
            this.handle_events ();

            restore_settings ();
            Application.settings.changed.connect (restore_settings);
            child_has_exited = false;

            child_exited.connect (() => {
                child_has_exited = true;
            });
        }

        public void restore_settings () {
            Gdk.RGBA background_color = Gdk.RGBA ();
            background_color.parse (Application.settings.get_string ("background-color"));
            Gdk.RGBA foreground_color = Gdk.RGBA ();
            foreground_color.parse (Application.settings.get_string ("foreground-color"));

            this.set_colors (foreground_color, background_color, null);

            Gdk.RGBA cursor_color = Gdk.RGBA ();
            cursor_color.parse (Application.settings.get_string ("cursor-color"));

            this.set_color_cursor (cursor_color);

            this.set_cursor_shape ((Vte.CursorShape) Application.settings.get_enum ("cursor-shape"));

            this.set_audible_bell (Application.settings.get_boolean ("audible-bell"));
        }

        public void run_program (string program_string, string? working_directory) {
            try {
                string[]? program_with_args = null;
                Shell.parse_argv (program_string, out program_with_args);
    
                this.spawn_async (Vte.PtyFlags.DEFAULT, working_directory, program_with_args, null, SpawnFlags.SEARCH_PATH, null, -1, null, terminal_callback);
            } catch (Error e) {
                warning (e.message);
                feed ((e.message + "\r\n\r\n").data);
                set_active_shell (working_directory);
            }
        }

        private void terminal_callback (Vte.Terminal terminal, GLib.Pid p, Error? error) {
            if (p != -1) {
                pid = p;
            } else {
                feed ((error.message + "\r\n\r\n").data);
            }
        }

        public void end_process () {
            while (Posix.kill (this.pid, 0) == 0) {
                Posix.kill (this.pid, Posix.Signal.HUP);
                Posix.kill (this.pid, Posix.Signal.TERM);
                Thread.usleep (100);
            }
        }

        public void set_active_shell (string? dir = GLib.Environment.get_current_dir ()) {
            string[] argv;
            string[] envv;
            Vte.PtyFlags flags = Vte.PtyFlags.DEFAULT;
            string shell;

            // Spawning works differently on host vs flatpak
            if (is_flatpak ()) {
              shell = fp_guess_shell () ?? "/usr/bin/bash";

              flags = Vte.PtyFlags.NO_CTTY;

              argv = {
                "/usr/bin/flatpak-spawn",
                "--host",
                "--watch-bus"
              };

              envv = fp_get_env () ?? Environ.get ();

              foreach (unowned string env in fenvv) {
                argv += @"--env=$(env)";
              }

              foreach (unowned string env in envv) {
                argv += @"--env=$(env)";
              }
            }
            else {
              envv = Environ.get ();

              foreach (unowned string env in fenvv) {
                envv += env;
              }

              shell = Environ.get_variable (envv, "SHELL");

              argv = {};

              flags = Vte.PtyFlags.DEFAULT;
            }

            argv += shell;

            this.spawn_async (
              flags,
              dir,
              argv,
              envv,
              0,
              null,
              -1,
              null,
              // For some reason, if I try using `err` here vala will generate the
              // following line at the top of this lambda function:
              //
              // g_return_if_fail (err != NULL);
              //
              // Which is insane, and does not work, since we expect error to be null
              // almost always.
              (_, _pid /*, err */) => {
                this.pid = (!) (_pid);
              }
            );
        }

        public bool is_flatpak() {
            return FileUtils.test("/.flatpak-info", FileTest.EXISTS);
        }

        /* fp_guess_shell
        *
        * Copyright 2019 Christian Hergert <chergert@redhat.com>
        *
        * The following function is a derivative work of the code from
        * https://gitlab.gnome.org/chergert/flatterm which is licensed under the
        * Apache License, Version 2.0 <LICENSE-APACHE or
        * https://opensource.org/licenses/MIT>, at your option. This file may not
        * be copied, modified, or distributed except according to those terms.
        *
        * SPDX-License-Identifier: (MIT OR Apache-2.0)
        */
        public string? fp_guess_shell(Cancellable? cancellable = null) throws Error {
            if (!is_flatpak())
              return Vte.get_user_shell();

            string[] argv = { "flatpak-spawn", "--host", "getent", "passwd",
              Environment.get_user_name() };

            var launcher = new GLib.SubprocessLauncher(
              SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_SILENCE
            );

            launcher.unsetenv("G_MESSAGES_DEBUG");
            var sp = launcher.spawnv(argv);

            if (sp == null)
              return null;

            string? buf = null;
            if (!sp.communicate_utf8(null, cancellable, out buf, null))
              return null;

            var parts = buf.split(":");

            if (parts.length < 7) {
              return null;
            }

            return parts[6].strip();
        }

        public string[]? fp_get_env(Cancellable? cancellable = null) throws Error {
            if (!is_flatpak())
              return Environ.get();

            string[] argv = { "flatpak-spawn", "--host", "env" };

            var launcher = new GLib.SubprocessLauncher(
              SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_SILENCE
            );

            launcher.setenv("G_MESSAGES_DEBUG", "false", true);

            var sp = launcher.spawnv(argv);

            if (sp == null)
              return null;

            string? buf = null;
            if (!sp.communicate_utf8(null, cancellable, out buf, null))
              return null;

            string[] arr = buf.strip().split("\n");

            return arr;
        }

        public string get_shell_location () {
            // It does. :)
            return this.get_current_directory_uri ();
        }

        public void reload () {
            if (try_get_foreground_pid (null)) {
                var dialog = new ProcessWarningDialog (
                    (Window) ((Gtk.Application) GLib.Application.get_default ()).active_window,
                    ProcessWarnType.TAB_RELOAD
                );

                dialog.returned.connect (() => {
                    dialog.destroy ();

                    reload_internal ();
                });
            } else {
                reload_internal ();
            }
        }

        public void get_link_uri (double x, double y) {
            link_uri = Fermion.Utils.get_pattern_at_coords (this, x, y);
        }

        private void reload_internal () {
            var old_loc = get_shell_location ();
            Posix.kill (this.pid, Posix.Signal.TERM);
            reset (true, true);
            set_active_shell (old_loc);
        }

        private void clickable (string[] str) {
            foreach (unowned string exp in str) {
                try {
                    var regex = new Vte.Regex.for_match (exp, -1, PCRE2.Flags.MULTILINE);
                    int id = this.match_add_regex (regex, 0);
                    this.match_set_cursor_name (id, "pointer");
                } catch (Error error) {
                    warning (error.message);
                }
            }
        }

        private void handle_events () {
            Gtk.GestureClick leftclick = new Gtk.GestureClick () {
                button = Gdk.BUTTON_PRIMARY
            };
            this.add_controller (leftclick);

            leftclick.pressed.connect ((n_presses, x, y) => {
               get_link_uri (x, y);
               if (link_uri != null && !this.get_has_selection ()) {
                   action_browser_handler (this);
               }
            });
        }
    }
}
