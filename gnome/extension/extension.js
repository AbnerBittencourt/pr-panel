import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';
import Clutter from 'gi://Clutter';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';

const PANEL_FILE = GLib.build_filenamev([GLib.get_user_state_dir(), 'pr-panel', 'panel.json']);
// Só abre PRs do GitHub: o arquivo é local e não deve conseguir disparar file:// ou outros esquemas.
const PR_URL = /^https:\/\/github\.com\/[^\s]+$/;
const CI_COLORS = {FAILURE: '#ff7b63', PENDING: '#f5c211', SUCCESS: '#57e389', SKIPPED: '#9a9996'};
const CI_PRIORITY = ['FAILURE', 'PENDING', 'SUCCESS'];
const REVIEW_LABELS = {APPROVED: 'aprovada', CHANGES_REQUESTED: 'pediram mudanças'};
const MAX_TITLE = 60;

function dotStyle(ci) {
    return `color: ${Object.hasOwn(CI_COLORS, ci) ? CI_COLORS[ci] : CI_COLORS.SKIPPED};`;
}

function shorten(title) {
    const text = String(title ?? '');
    return text.length > MAX_TITLE ? `${text.slice(0, MAX_TITLE - 1)}…` : text;
}

function isPanel(panel) {
    const isList = list => Array.isArray(list) && list.every(pr => pr && typeof pr === 'object');
    return isList(panel?.mine) && isList(panel?.requested);
}

export default class PrPanelExtension extends Extension {
    enable() {
        this._button = new PanelMenu.Button(0.0, this.metadata.name);
        const box = new St.BoxLayout({style_class: 'panel-status-menu-box'});
        this._dot = new St.Label({text: '●', y_align: Clutter.ActorAlign.CENTER, visible: false});
        this._label = new St.Label({text: 'PRs …', y_align: Clutter.ActorAlign.CENTER});
        box.add_child(this._dot);
        box.add_child(this._label);
        this._button.add_child(box);
        Main.panel.addToStatusArea(this.uuid, this._button);

        // O pr-panel-update troca o arquivo a cada 3 min; o monitor evita qualquer chamada ao GitHub daqui.
        this._monitor = Gio.File.new_for_path(PANEL_FILE).monitor_file(Gio.FileMonitorFlags.WATCH_MOVES, null);
        this._monitor.connect('changed', () => this._reload());
        this._reload();
    }

    disable() {
        this._monitor.cancel();
        this._monitor = null;
        this._button.destroy();
        this._button = null;
        this._dot = null;
        this._label = null;
    }

    _reload() {
        let panel;
        try {
            const [, bytes] = GLib.file_get_contents(PANEL_FILE);
            panel = JSON.parse(new TextDecoder().decode(bytes));
        } catch {
            return;
        }
        if (!isPanel(panel))
            return;
        const worst = CI_PRIORITY.find(ci => panel.mine.some(pr => pr.ci === ci));
        const reviews = panel.requested.length ? ` · ${panel.requested.length} review` : '';
        this._dot.visible = Boolean(worst);
        this._dot.style = worst ? `${dotStyle(worst)} margin-right: 6px;` : '';
        this._label.text = `PRs ${panel.mine.length}${reviews}`;
        this._buildMenu(panel);
    }

    _buildMenu(panel) {
        const menu = this._button.menu;
        menu.removeAll();
        menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem('Minhas PRs'));
        for (const pr of panel.mine) {
            const review = REVIEW_LABELS[pr.review] ? ` · ${REVIEW_LABELS[pr.review]}` : '';
            this._addPr(pr, review, pr.ci);
        }
        if (panel.requested.length) {
            menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem('Pedindo seu review'));
            for (const pr of panel.requested)
                this._addPr(pr, '');
        }
        const footer = new PopupMenu.PopupMenuItem(`Atualizado às ${panel.updated}`, {reactive: false});
        menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        menu.addMenuItem(footer);
    }

    _addPr(pr, suffix, ci) {
        const item = new PopupMenu.PopupBaseMenuItem();
        if (ci !== undefined)
            item.add_child(new St.Label({text: '●', style: dotStyle(ci), y_align: Clutter.ActorAlign.CENTER}));
        item.add_child(new St.Label({
            text: `${pr.repo} #${pr.number} — ${shorten(pr.title)}${suffix}`,
            y_align: Clutter.ActorAlign.CENTER,
        }));
        if (typeof pr.url === 'string' && PR_URL.test(pr.url))
            item.connect('activate', () => Gio.AppInfo.launch_default_for_uri(pr.url, null));
        else
            item.reactive = false;
        this._button.menu.addMenuItem(item);
    }
}
