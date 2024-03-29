/* dialogs/unsafe_paste.vala
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
    [GtkTemplate (ui = "/com/fyralabs/Fermion/dialogs/unsafe_paste.ui")]
    public class UnsafePasteDialog : He.Dialog {
        public signal void returned ();

        [GtkCallback]
        public void paste_anyway () {
            returned ();
        }
        
        public UnsafePasteDialog (Fermion.Window parent, string title_text, string pasted_text) {
            Object (
                title: title_text,
                subtitle: @"<i><tt>$(pasted_text)</tt></i>"
            );

            info = @"Copying commands from the internet can be dangerous. Be sure you understand what each part of the pasted text does before continuing.\n\nYou may disable this dialog in Settings";

            this.set_parent (parent);

            this.present ();
        }
    }
}
