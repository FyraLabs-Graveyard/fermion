/* handlers/mouse.vala
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
    public void action_browser_handler (TerminalWidget terminal) {
        Fermion.Utils.get_current_selection_link_or_pwd (terminal, terminal.link_uri, (uri) => {
            var to_open = Fermion.Utils.sanitize_path (uri, terminal.get_shell_location ());

            if (to_open != null) {
                Gtk.show_uri (null, to_open, Gdk.CURRENT_TIME);
            }
        });
    }
}
