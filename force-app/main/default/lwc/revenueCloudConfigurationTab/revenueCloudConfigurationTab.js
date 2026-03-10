import { LightningElement, api } from 'lwc';

export default class RevenueCloudConfigurationTab extends LightningElement {

    @api items = [];
    @api type;
    title;
    selectedItemCount = 0;
    searchTerm = '';
    selectedLastModifiedDate = '';
    selectedLastModifiedBy = '';
    selectedStatus = '';
    columns = [
        { label: 'Name', fieldName: 'label' },
        { label: 'API Name', fieldName: 'value' },
        { label: 'Last Modified Date', fieldName: 'lastModifiedDate', type: 'date' },
        { label: 'Last Modified By', fieldName: 'lastModifiedBy', type: 'text' },
        { label: "Status", type: "customBadgeType", typeAttributes: { badgeLabel: { fieldName: "status" }, badgeIcon: { fieldName: "statusIcon" }, badgeColor: { fieldName: "statusColor" } } },
    ];

    get lastModifiedDateOptions() {
        return [
            { label: 'Anytime', value: '' },
            { label: 'Today', value: 'today' },
            { label: 'This Week', value: 'thisWeek' },
            { label: 'This Month', value: 'thisMonth' }
        ];
    }

    get lastModifiedByOptions() {
        const users = new Set();
        this.items.forEach(item => {
            if (item.lastModifiedBy) {
                users.add(item.lastModifiedBy);
            }
        });
        return [
            { label: 'All Users', value: '' },
            ...Array.from(users).sort().map(user => ({ label: user, value: user }))
        ];
    }

    get statusOptions() {
        const statuses = new Set();
        this.items.forEach(item => {
            if (item.status) {
                statuses.add(item.status);
            }
        });
        return [
            { label: 'All Statuses', value: '' },
            ...Array.from(statuses).sort().map(status => ({ label: status, value: status }))
        ];
    }

    get filteredItems() {
        let filtered = this.items;

        // Apply search filter
        if (this.searchTerm) {
            filtered = filtered.filter(item =>
                item.label && item.label.toLowerCase().includes(this.searchTerm.toLowerCase())
            );
        }

        // Apply last modified date filter
        if (this.selectedLastModifiedDate) {
            const now = new Date();
            const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
            
            filtered = filtered.filter(item => {
                if (!item.lastModifiedDate) return false;
                
                const itemDate = new Date(item.lastModifiedDate);
                const itemDateOnly = new Date(itemDate.getFullYear(), itemDate.getMonth(), itemDate.getDate());
                
                switch(this.selectedLastModifiedDate) {
                    case 'today':
                        return itemDateOnly.getTime() === today.getTime();
                    
                    case 'thisWeek':
                        // Get the start of this week (Sunday)
                        const weekStart = new Date(today);
                        weekStart.setDate(today.getDate() - today.getDay());
                        return itemDateOnly >= weekStart && itemDateOnly <= today;
                    
                    case 'thisMonth':
                        return itemDate.getMonth() === now.getMonth() && 
                               itemDate.getFullYear() === now.getFullYear();
                    
                    default:
                        return true;
                }
            });
        }

        // Apply last modified by filter
        if (this.selectedLastModifiedBy) {
            filtered = filtered.filter(item =>
                item.lastModifiedBy === this.selectedLastModifiedBy
            );
        }

        // Apply status filter
        if (this.selectedStatus) {
            filtered = filtered.filter(item =>
                item.status === this.selectedStatus
            );
        }

        return filtered;
    }

    get selectedRowKeys() {
        return this.items
            .filter(item => item.selected === true)
            .map(item => item.value);
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleLastModifiedDateChange(event) {
        this.selectedLastModifiedDate = event.detail.value;
    }

    handleLastModifiedByChange(event) {
        this.selectedLastModifiedBy = event.detail.value;
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
    }

    renderedCallback() {
        if(this.type === 'standard') {
            this.title = 'Product Configuration Rules';
        } else if(this.type === 'advanced') {
            this.title = 'Advanced Rules / Constraints';
        } else if(this.type === 'automation') {
            this.title = 'Automations';
        }
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedItemCount = selectedRows.length;

        // Dispatch an event to notify parent component about the selection change
        const selectionEvent = new CustomEvent('selectionchange', {
            detail: {
                type: this.type,
                selectedItems: selectedRows
            }
        });
        this.dispatchEvent(selectionEvent);
    }
}