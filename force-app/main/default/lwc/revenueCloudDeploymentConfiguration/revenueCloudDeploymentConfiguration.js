import { LightningElement, api, track } from 'lwc';
import getItemsByType from '@salesforce/apex/RevenueCloudConfiguratorController.retrieveItemsFromCacheByType';
import refreshItems from '@salesforce/apex/RevenueCloudConfiguratorController.retrieveItemsFromSource';
import pollRetrieval from '@salesforce/apex/RevenueCloudConfiguratorController.pollRetrievalStatus';
import processSelectedStandardRules from '@salesforce/apex/RevenueCloudConfiguratorController.processSelectedConfigurationRules';
import processSelectedAdvancedRules from '@salesforce/apex/RevenueCloudConfiguratorController.processSelectedAdvancedConfigurationRules';
import processSelectedAutomations from '@salesforce/apex/RevenueCloudConfiguratorController.processSelectedAutomations';
import getTargetEnvironmentName from '@salesforce/apex/RevenueCloudConfiguratorController.getTargetEnvironmentName';

import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class RevenueCloudDeploymentConfiguration extends LightningElement {

    @track standardRules = [];
    @track advancedRules = [];
    @track automationRules = [];

    lastRefreshDate;
    targetEnvironmentName;
    selectedItemCount = 0;
    selectedItemCountStandard = 0;
    selectedItemCountAdvanced = 0;
    selectedItemCountAutomation = 0;

    selectedStandardRules = [];
    selectedAdvancedRules = [];
    selectedAutomationRules = [];

    showStandardRules = true;
    showAdvancedRules = false;
    showAutomationRules = false;

    isDisabledAddChanges = true;
    showSelectionReadyMessage = false;
    isComponentReady = false;
    isInitialized = false;
    componentReadyCounter = 0;
    showSpinner = false;
    pollingInterval;
    progressMessage = '';
    showProgressMessage = false;

    @api 
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;
        if (value && !this.isInitialized) {
            this.isInitialized = true;
            this.showSpinner = true;
            this.loadItems();
        }
    }  

    get standardRulesCount() {
        return this.standardRules.length;
    }

    get advancedRulesCount() {
        return this.advancedRules.length;
    }
    get automationRulesCount() {
        return this.automationRules.length;
    }

    get iconStyle() {
        return `font-size: ${this.getSize(this.iconSize)};`;
    }

    disconnectedCallback() {
        this.stopPolling();
    }

    loadItems() {
        this.retrieveItemsByType('standard');
        this.retrieveItemsByType('advanced');
        this.retrieveItemsByType('automation');
        this.fetchTargetEnvironmentName();
    }

    fetchTargetEnvironmentName() {
        getTargetEnvironmentName({ recordId: this.recordId })
            .then(result => {
                this.targetEnvironmentName = result;
            })
            .catch(error => {
                console.error('Error fetching target environment name:', error);
            });
    }

    retrieveItemsByType(type) {
        getItemsByType({ recordId: this.recordId, type: type })
            .then(result => {
                this.updateListItems(result);
                this.componentReadyCounter++;
                this.isComponentReady = (this.componentReadyCounter >= 3);
                if(!this.isComponentReady) {
                    this.progressMessage = `Loading... (${this.componentReadyCounter}/3)`;
                    this.showProgressMessage = true;
                } else {
                    this.showSpinner = false;
                    this.showProgressMessage = false;
                    this.progressMessage = '';
                }
            })
            .catch(error => {
                this.showSpinner = false;
                this.showProgressMessage = false;
                this.progressMessage = 'An error occurred while loading items.';
                console.error('Error retrieving items:', error);
            });
    }

    handleRefresh() {
        this.showSpinner = true;
        refreshItems({ recordId: this.recordId })
            .then(resultId => {
                this.startPolling(resultId);
            })
            .catch(error => {
                console.error('Error initiating refresh:', error);
            });
    }

    startPolling(resultId) {
        this.showSpinner = true;
        this.pollRetrievalStatus(resultId);
        this.pollingInterval = setInterval(() => {
            this.pollRetrievalStatus(resultId);
        }, 3000);
    }

    stopPolling() {
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
            this.pollingInterval = undefined;
            this.showSpinner = false;
        }
    }

    pollRetrievalStatus(resultId) {
        pollRetrieval({ recordId: this.recordId, resultId: resultId })
            .then(result => {
                if(result) {
                    if(result?.startsWith('In Progress:')) {
                        this.progressMessage = result;
                        this.showProgressMessage = true;
                    } else if(result === 'error') {
                        this.stopPolling();
                    } else {
                        this.stopPolling();
                        this.loadItems();
                        this.showSpinner = false;
                        this.showProgressMessage = false;
                        this.progressMessage = '';
                    }
                } else {
                    this.showSpinner = false;
                    this.showError = true;
                }
            })
            .catch(error => {
                console.error('Error polling retrieval status:', error);
                this.stopPolling();
            });
    }

    updateListItems(result) {
        this.lastRefreshDate = result.lastRefreshDate;

        if(result.type === 'standard') {
            this.standardRules = [...result.items];
            console.log('Standard rules updated:', this.standardRules);
        } else if(result.type === 'advanced') {
            this.advancedRules = [...result.items];
        } else if(result.type === 'automation') {
            this.automationRules = [...result.items];
        }
    }

    handleSectionChange(event) {
        const selectedSection = event.currentTarget.dataset.section;
        const buttons = this.template.querySelectorAll('.button-bar-btn');
        buttons.forEach(button => {
            if(button.dataset.section === selectedSection) {
                button.classList.add('is-active');
            } else {
                button.classList.remove('is-active');
            }
        });

        if(selectedSection === 'standard_rules') {
            this.showStandardRules = true;
            this.showAdvancedRules = false;
            this.showAutomationRules = false;
        } else if(selectedSection === 'advanced_rules') {
            this.showStandardRules = false;
            this.showAdvancedRules = true;
            this.showAutomationRules = false;
        } else if(selectedSection === 'automations') {
            this.showStandardRules = false;
            this.showAdvancedRules = false;
            this.showAutomationRules = true;
        }

    }

    handleStandardSelectionChange(event) {
        this.selectedItemCountStandard = event.detail.selectedItems.length;
        this.selectedStandardRules = event.detail.selectedItems;
        this.updateAddChangesState();
    }

    handleAdvancedSelectionChange(event) {
        this.selectedItemCountAdvanced = event.detail.selectedItems.length;
        this.selectedAdvancedRules = event.detail.selectedItems;
        this.updateAddChangesState();
    }

    handleAutomationSelectionChange(event) {
        this.selectedItemCountAutomation = event.detail.selectedItems.length;
        this.selectedAutomationRules = event.detail.selectedItems;
        this.updateAddChangesState();
    }

    updateAddChangesState() {
        this.selectedItemCount = this.selectedItemCountStandard + this.selectedItemCountAdvanced + this.selectedItemCountAutomation;
        this.isDisabledAddChanges = this.selectedItemCount === 0;
        this.showSelectionReadyMessage = !this.isDisabledAddChanges;
    }

    handleAddChanges(){
        this.showSpinner = true;
        if(this.selectedItemCountStandard > 0) {
            let selectedItemApiNames = this.selectedStandardRules.map(item => item.value);
            processSelectedStandardRules({ selectedItems: selectedItemApiNames, recordId: this.recordId })
                .then(() => {
                    this.showSpinner = false;
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success',
                        message: 'Selected product configuration rules added to the user story successfully.',
                        variant: 'success'
                    }));
                    this.dispatchEvent(new CloseActionScreenEvent());
                })
                .catch(error => {
                    this.showSpinner = false;
                    console.error('Error processing selected standard rules:', error);
                });

        }
        if(this.selectedItemCountAdvanced > 0) {
            let selectedItemApiNames = this.selectedAdvancedRules.map(item => item.value);
            processSelectedAdvancedRules({ selectedItems: selectedItemApiNames, recordId: this.recordId })
                .then(() => {
                    this.showSpinner = false;
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success',
                        message: 'Selected product advanced rules added to the user story successfully.',
                        variant: 'success'
                    }));
                    this.dispatchEvent(new CloseActionScreenEvent());
                })
                .catch(error => {
                    this.showSpinner = false;
                    console.error('Error processing selected advanced rules:', error);
                });
        }
        if(this.selectedItemCountAutomation > 0) {
            let selectedItemApiNames = this.selectedAutomationRules.map(item => item.value);
            processSelectedAutomations({ selectedItems: selectedItemApiNames, recordId: this.recordId })
                .then(() => {
                    this.showSpinner = false;
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success',
                        message: 'Selected product automations added to the user story successfully.',
                        variant: 'success'
                    }));
                    this.dispatchEvent(new CloseActionScreenEvent());
                })
                .catch(error => {
                    this.showSpinner = false;
                    console.error('Error processing selected automation rules:', error);
                });
        }
    }
}