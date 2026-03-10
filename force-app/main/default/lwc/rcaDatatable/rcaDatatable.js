import LightningDatatable from 'lightning/datatable';
import customBadge from './customBadge.html';

export default class RcaDatatable extends LightningDatatable {
    static customTypes = {
        customBadgeType: {
            template: customBadge,
            standardCellLayout: true,
            typeAttributes: ['badgeLabel', 'badgeIcon', 'badgeColor']
        }
    };
}