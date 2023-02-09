/* dialogs/process.vala
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
    public enum ProcessWarnType {
        TAB_CLOSE,
        TAB_RELOAD,
        TERMINAL_CLOSE,
    }

    [GtkTemplate (ui = "/com/fyralabs/Fermion/dialogs/process.ui")]
    public class ProcessWarningDialog : He.Dialog {
        public signal void returned ();

        [GtkChild] private unowned He.FillButton btn;

        [GtkCallback]
        public void do_close () {
            returned ();
        }

        public ProcessWarningDialog (Fermion.Window parent, ProcessWarnType type) {
            var subject = "";
            var label = "";

            if (type == ProcessWarnType.TAB_CLOSE) {
                subject = "close this tab";
                label = "Close Anyway";
            } else if (type == ProcessWarnType.TAB_RELOAD) {
                subject = "reload this tab";
                label = "Reload Anyway";
            } else if (type == ProcessWarnType.TERMINAL_CLOSE) {
                subject = "quit Terminal";
                label = "Quit Anyway";
            }

            Object (
                title: @"Are you sure you want to $(subject)?",
                info: @"There is an active process on this $(type == ProcessWarnType.TERMINAL_CLOSE ? "terminal" : "tab"). If you $(subject), the process will end."
            );

            btn.set_label (label);

            this.set_parent (parent);

            this.present ();
        }
    }
}
