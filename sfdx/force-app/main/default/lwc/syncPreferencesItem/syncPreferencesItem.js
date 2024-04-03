import { LightningElement, api } from 'lwc';
import Debugger from "c/debugger";

export default class SyncPreferencesItem extends LightningElement {
    @api name;
    @api toggleFieldVisibilityList;

    // controls if the widget is hidden by default
    @api hidden = false;

    // not proud of this but needed a simple way to remove the added margin for the first item in 'Sync Filters'
    @api first = false;

    get displayItem() {
        // console.log('name', this.name);
        Debugger.log('toggleFieldVisibilityList', this.toggleFieldVisibilityList);
        const isInToggleList = this.toggleFieldVisibilityList && this.toggleFieldVisibilityList.indexOf(this.name) !== -1;
        if (this.hidden) {
            // if it is not visible by default, then it must be in toggleFieldVisibilityList to be visible
            return isInToggleList;
        } else {
            // if it is visible by default, then it must not be in toggleFieldVisibilityList to still be visible
            return isInToggleList === false;
        }

    }

    get className() {
        const activeClass = this.first ? 'stripe-settings__item_first' : 'stripe-settings__item';
        return this.displayItem ? activeClass : 'stripe-settings__item_disabled';
    }
}