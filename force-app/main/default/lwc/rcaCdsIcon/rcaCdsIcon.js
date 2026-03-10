import { LightningElement, api } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';

import COPADO_ICON from '@salesforce/resourceUrl/copadoIcons';

export default class RcaCdsIcon extends LightningElement {
    @api iconName;
    @api iconSize;

    get iconClass() {
        return `cds-icon--copado copa-icon ${this.iconName.replace(/^copado\:/i, '')}`;
    }

    get iconStyle() {
        return `font-size: ${this.getSize(this.iconSize)};`;
    }

    getSize() {
        const sizes = {
            'xx-small': '14px',
            'x-small': '16px',
            'xs-plus': '18px',
            small: '24px',
            medium: '32px',
            large: '48px'
        };
        return sizes[this.iconSize] || '1rem';
    }

    connectedCallback() {
        loadStyle(this, COPADO_ICON + '/copadoIcons/copado-icon.css');
    }
}