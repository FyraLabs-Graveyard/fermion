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
        private He.Desktop desktop;

        internal const string DEFAULT_LABEL = "Fermion";
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

        public const int SYS_PIDFD_OPEN = 434; // Same on every arch

        public bool child_has_exited {
            get;
            private set;
        }
        public bool killed {
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

            child_has_exited = false;
            killed = false;

            desktop = new He.Desktop ();
            restore_settings (desktop);
            desktop.notify["prefers-color-scheme"].connect (() => {
                restore_settings (desktop);
            });

            child_exited.connect (on_child_exited);
        }

        public void restore_settings (He.Desktop desktop) {
            var theme_palette = new Gdk.RGBA[19];
            theme_palette = get_rgba_palette (desktop);
            var background = theme_palette[19 - 3];
            var foreground = theme_palette[19 - 2];
            var cursor = theme_palette[19 - 1];
            var palette = theme_palette[0:16];

            this.set_colors (foreground, background, palette);
            this.set_color_cursor (cursor);

            this.set_cursor_shape ((Vte.CursorShape) Application.settings.get_enum ("cursor-shape"));

            this.set_audible_bell (Application.settings.get_boolean ("audible-bell"));
        }

        // format is color01:color02:...:color16:background:foreground:cursor
        public static Gdk.RGBA[] get_rgba_palette (He.Desktop desktop) {
            var string_palette = get_string_palette (desktop);
            var rgba_palette = new Gdk.RGBA[19];
            for (int i = 0; i < 19; i++) {
                var new_color = Gdk.RGBA ();
                new_color.parse(string_palette[i]);
                rgba_palette[i] = new_color;
            }

            return rgba_palette;
        }
        private static string[] get_string_palette (He.Desktop desktop) {
            var string_palette = new string[19];

            if (He.Desktop.ColorScheme.DARK == desktop.prefers_color_scheme) {
                string_palette = {
                    // Dark colors, KRGYBMCW
                    "#2d2d2d", "#b21e4c", "#2fb744", "#e0a101", "#0674e6", "#9f3c89", "#38947e", "#ababb6",
                    // Light colors, KRGYBMCW
                    "#6a6a6a", "#db2860", "#49d05e", "#febc16", "#268ef9", "#bf56a8", "#56bfa6", "#fafafa",
                    // BG, FG, C
                    "#2d2d2d", "#f0f0f2", "#828292"
                };
            } else {
                string_palette = {
                    // Dark colors, KRGYBMCW
                    "#2d2d2d", "#b21e4c", "#2fb744", "#e0a101", "#0674e6", "#9f3c89", "#38947e", "#ababb6",
                    // Light colors, KRGYBMCW
                    "#6a6a6a", "#db2860", "#49d05e", "#febc16", "#268ef9", "#bf56a8", "#56bfa6", "#fafafa",
                    // BG, FG, C
                    "#f0f0f2", "#2d2d2d", "#828292"
                };
            }
            Application.settings.set_string ("palette", string.joinv (":", string_palette));
            return string_palette;
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
            killed = true;

#if HAS_LINUX
            int pid_fd = Linux.syscall (SYS_PIDFD_OPEN, this.pid, 0);
#else
            int pid_fd = -1;
#endif

            Posix.kill (this.pid, Posix.Signal.HUP);
            Posix.kill (this.pid, Posix.Signal.TERM);

            // pidfd_open isn't supported in Linux kernel < 5.3
            if (pid_fd == -1) {
#if HAS_GLIB_2_74
                // GLib 2.73.2 dropped global GChildWatch, we need to wait ourselves
                Posix.waitpid (this.pid, null, 0);
#else
                while (Posix.kill (this.pid, 0) == 0) {
                    Thread.usleep (100);
                }
#endif
                return;
            }

            Posix.pollfd pid_pfd[1];
            pid_pfd[0] = Posix.pollfd () {
                fd = pid_fd,
                events = Posix.POLLIN
            };

            // The loop deals the case when SIGCHLD is delivered to us and restarts the call
            while (Posix.poll (pid_pfd, -1) != 1) {}

            Posix.close (pid_fd);
        }
        public void kill_fg () {
            int fg_pid;
            if (this.try_get_foreground_pid (out fg_pid))
                Posix.kill (fg_pid, Posix.Signal.KILL);
        }
        void on_child_exited () {
            child_has_exited = true;
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
