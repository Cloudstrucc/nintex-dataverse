// ========================================
// CS Basic Form Library v1.2
// Cloudstrucc Form Enhancement Toolkit
// ========================================
//
// DESCRIPTION:
// A comprehensive JavaScript library for enhancing Power Pages/Portal forms
// with improved styling, lookup modal handling, and rich text editing capabilities.
// Designed to provide consistent, professional form experiences across
// Microsoft Power Pages implementations.
//
// USAGE:
// 1. Include this script in your Power Pages web template or custom JavaScript
// 2. Initialize with optional configuration:
//
//    CSBasicForm.init({
//      colors: {
//        primary: '#2b4380',      // Primary button/accent color
//        primaryHover: '#1e2f5a', // Hover state for primary elements
//        secondary: '#2C5F6F'     // Secondary color (modal headers)
//      },
//      richTextFields: ['cr123_description', 'cr123_notes'], // Field schema names
//      features: {
//        lookupButtons: true,     // Style lookup field buttons
//        lookupModals: true,      // Fix lookup modal display/selection
//        calendarButtons: true,   // Style date picker buttons
//        submitButton: true,      // Style form submit button
//        richTextEditor: true     // Enable Quill rich text editors
//      }
//    });
//
// AVAILABLE METHODS:
// ──────────────────────────────────────────────────────────────────────────────
// CSBasicForm.init(config)
//   Main initialization method. Call once on page load.
//   @param {Object} config - Optional configuration object (see USAGE above)
//
// CSBasicForm.applyStyles()
//   Applies CSS styling for buttons, inputs, and form controls.
//   Called automatically by init() if relevant features are enabled.
//
// CSBasicForm.cleanLookupButtons()
//   Removes unwanted text from lookup field buttons, leaving only icons.
//   Called automatically by init() if lookupButtons feature is enabled.
//
// CSBasicForm.initLookupModalFixes()
//   Applies styling fixes to lookup modal dialogs (headers, colors, text cleanup).
//   Called automatically by init() if lookupModals feature is enabled.
//
// CSBasicForm.initLookupModalDisplay()
//   Handles visibility and z-index issues for lookup modals, especially
//   when opened from within another modal (nested modal scenario).
//   Called automatically by init() if lookupModals feature is enabled.
//
// CSBasicForm.initLookupSelectionHandler()
//   Manages record selection within lookup modals, including checkbox
//   toggling, Select button enabling, and populating the parent form field.
//   Called automatically by init() if lookupModals feature is enabled.
//
// CSBasicForm.initRichTextEditor(fieldName)
//   Converts a textarea field into a Quill rich text editor.
//   @param {string} fieldName - The schema name of the field (e.g., 'cr123_notes')
//   Can be called manually or automatically via richTextFields config array.
//
// CONFIGURATION OBJECT REFERENCE:
// ──────────────────────────────────────────────────────────────────────────────
// {
//   colors: {
//     primary: string,       // Default: '#2b4380' - Main accent color
//     primaryHover: string,  // Default: '#1e2f5a' - Hover state color
//     secondary: string      // Default: '#2C5F6F' - Modal header color
//   },
//   richTextFields: string[], // Array of field schema names for rich text
//   features: {
//     lookupButtons: boolean,   // Default: true
//     lookupModals: boolean,    // Default: true
//     calendarButtons: boolean, // Default: true
//     submitButton: boolean,    // Default: true
//     richTextEditor: boolean   // Default: true
//   }
// }
//
// DEPENDENCIES:
// - Quill.js v1.3.6 (loaded automatically when rich text is enabled)
// - Font Awesome (expected to be present in Power Pages)
//
// COMPATIBILITY:
// - Microsoft Power Pages / Power Apps Portals
// - Bootstrap 3.x and 4.x modal structures
// - Modern browsers (Chrome, Firefox, Edge, Safari)
//
// ========================================

window.CSBasicForm = window.CSBasicForm || {};

(function(CS) {
  'use strict';
  
  // Configuration defaults
  CS.config = {
    colors: {
      primary: '#2b4380',
      primaryHover: '#1e2f5a',
      secondary: '#2C5F6F'
    },
    richTextFields: [],
    features: {
      lookupButtons: true,
      lookupModals: true,
      calendarButtons: true,
      submitButton: true,
      richTextEditor: true
    }
  };
  
  // ========================================
  // STYLING MODULE
  // ========================================
  CS.applyStyles = function() {
    console.log('🎨 Applying CS styles');
    
    const style = document.createElement('style');
    style.id = 'cs-basicform-styles';
    style.textContent = `
      :root {
        --cs-primary: ${CS.config.colors.primary};
        --cs-primary-hover: ${CS.config.colors.primaryHover};
        --cs-secondary: ${CS.config.colors.secondary};
      }
      
      /* Lookup buttons */
      .control .input-group .btn.clearlookupfield,
      .control .input-group .btn.launchentitylookup {
        background-color: var(--cs-primary) !important;
        border-color: var(--cs-primary) !important;
        color: white !important;
        width: 44px !important;
        min-width: 44px !important;
        max-width: 44px !important;
        padding: 0 !important;
        font-size: 0 !important;
        display: flex !important;
        align-items: center !important;
        justify-content: center !important;
      }
      
      .control .input-group .btn:hover {
        background-color: var(--cs-primary-hover) !important;
        border-color: var(--cs-primary-hover) !important;
      }
      
      .control .input-group .btn .fa,
      .control .input-group .btn [class*="fa-"] {
        font-size: 16px !important;
        color: white !important;
        display: block !important;
      }
      
      .control .input-group .btn .visually-hidden,
      .control .input-group .btn .sr-only {
        display: none !important;
      }
      
      /* Calendar button */
      .control .datetimepicker .input-group-addon {
        background-color: var(--cs-primary) !important;
        border-color: var(--cs-primary) !important;
        color: white !important;
        width: 44px !important;
        min-width: 44px !important;
        padding: 0 !important;
        display: flex !important;
        align-items: center !important;
        justify-content: center !important;
      }
      
      .control .datetimepicker .input-group-addon .fa {
        font-size: 16px !important;
        color: white !important;
      }
      
      /* Submit button */
      .actions .btn-primary,
      button[type="submit"].btn-primary {
        background-color: var(--cs-primary) !important;
        border-color: var(--cs-primary) !important;
        color: white !important;
        padding: 10px 24px !important;
        font-size: 16px !important;
        font-weight: 500 !important;
      }
      
      .actions .btn-primary:hover {
        background-color: var(--cs-primary-hover) !important;
      }
      
      /* Focus states */
      .form-control:focus {
        border-color: var(--cs-primary) !important;
        box-shadow: 0 0 0 0.2rem rgba(43, 67, 128, 0.25) !important;
      }
      
      /* Full width inputs */
      .control input.form-control:not(.lookup),
      .control textarea.form-control,
      .control select.form-control {
        width: 100% !important;
        max-width: 100% !important;
      }
      
      /* Lookup input group */
      .control .input-group {
        display: flex !important;
        flex-direction: row !important;
      }
      
      .control .input-group input.lookup {
        flex: 1 1 auto !important;
        border-right: none !important;
        border-radius: 4px 0 0 4px !important;
      }
      
      .control .input-group .btn:first-of-type {
        border-radius: 0 !important;
        border-left: none !important;
        border-right: none !important;
      }
      
      .control .input-group .btn:last-of-type {
        border-radius: 0 4px 4px 0 !important;
        border-left: none !important;
      }
    `;
    
    document.head.appendChild(style);
    console.log('✅ Styles applied');
  };
  
  // ========================================
  // LOOKUP BUTTON CLEANER
  // ========================================
  CS.cleanLookupButtons = function() {
    setTimeout(function() {
      const buttons = document.querySelectorAll('.btn.clearlookupfield, .btn.launchentitylookup');
      buttons.forEach(function(btn) {
        Array.from(btn.childNodes).forEach(function(node) {
          if (node.nodeType === Node.TEXT_NODE) {
            node.textContent = '';
          }
        });
      });
      console.log('✅ Cleaned lookup buttons');
    }, 500);
  };
  
  // ========================================
  // LOOKUP MODAL FIXES (STYLING)
  // ========================================
  CS.initLookupModalFixes = function() {
    console.log('🔧 Initializing lookup modal styling fixes');
    
    // Clean modal text
    const cleanModal = function() {
      // Close button
      const closeButtons = document.querySelectorAll('.modal-lookup .modal-header .close, .modal-lookup .modal-header .form-close');
      closeButtons.forEach(function(btn) {
        while (btn.firstChild) btn.removeChild(btn.firstChild);
        btn.textContent = '×';
        btn.style.fontSize = '32px';
      });
      
      // Search button
      const searchButtons = document.querySelectorAll('.modal-lookup .entitylist-search .btn-default, .modal-lookup .view-search .btn-default');
      searchButtons.forEach(function(btn) {
        const icon = btn.querySelector('.fa');
        if (icon) {
          Array.from(btn.childNodes).filter(n => n.nodeType === Node.TEXT_NODE).forEach(n => n.remove());
          btn.querySelectorAll('.visually-hidden, .sr-only').forEach(s => s.remove());
        }
      });
      
      // Column headers
      const headers = document.querySelectorAll('.modal-lookup .view-grid table thead th a');
      headers.forEach(function(header) {
        let cleanText = header.textContent.split('↑')[0].split('↓')[0].split('.')[0];
        cleanText = cleanText.replace(/\s+sort\s+(ascending|descending)/gi, '').trim();
        if (cleanText) {
          while (header.firstChild) header.removeChild(header.firstChild);
          header.textContent = cleanText;
        }
      });
    };
    
    // Fix colors
    const fixColors = function() {
      document.querySelectorAll('.modal-lookup').forEach(function(modal) {
        const header = modal.querySelector('.modal-header');
        if (header) {
          header.style.setProperty('background-color', CS.config.colors.secondary, 'important');
          header.style.setProperty('color', 'white', 'important');
          
          const title = header.querySelector('.modal-title, h2, h3');
          if (title) title.style.setProperty('color', 'white', 'important');
          
          const closeBtn = header.querySelector('.close, .form-close, button[data-bs-dismiss]');
          if (closeBtn) {
            closeBtn.style.setProperty('color', 'white', 'important');
            closeBtn.style.setProperty('opacity', '1', 'important');
          }
        }
      });
    };
    
    // Remove h1 underlines
    const removeUnderlines = function() {
      document.querySelectorAll('.modal-lookup').forEach(function(modal) {
        modal.querySelectorAll('h1, .modal-title, h2, h3').forEach(function(h1) {
          h1.style.setProperty('border', 'none', 'important');
          h1.style.setProperty('border-bottom', 'none', 'important');
          h1.style.setProperty('text-decoration', 'none', 'important');
          h1.style.setProperty('box-shadow', 'none', 'important');
          h1.style.setProperty('outline', 'none', 'important');
          h1.style.setProperty('background-image', 'none', 'important');
        });
      });
    };
    
    // Apply all fixes when lookup button clicked
    document.addEventListener('click', function(e) {
      if (e.target.closest('.launchentitylookup')) {
        [100, 300, 600, 1000].forEach(delay => {
          setTimeout(cleanModal, delay);
          setTimeout(fixColors, delay);
          setTimeout(removeUnderlines, delay);
        });
      }
    }, true);
    
    // Watch for modals appearing
    const observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
          const target = mutation.target;
          if (target.classList && target.classList.contains('modal-lookup') && target.classList.contains('show')) {
            setTimeout(cleanModal, 50);
            setTimeout(fixColors, 50);
            setTimeout(removeUnderlines, 50);
          }
        }
      });
    });
    
    observer.observe(document.body, {
      attributes: true,
      attributeFilter: ['class'],
      subtree: true
    });
    
    console.log('✅ Lookup modal styling fixes initialized');
  };
  
  // ========================================
  // LOOKUP MODAL DISPLAY HANDLER (FOR NESTED MODALS)
  // ========================================
  CS.initLookupModalDisplay = function() {
    console.log('🔍 Initializing lookup modal display handler');
    
    let lastClickTime = 0;
    let modalShown = false;
    
    // Detect lookup button clicks
    document.addEventListener('click', function(e) {
      const lookupButton = e.target.closest('.launchentitylookup');
      if (lookupButton) {
        console.log('🎯 Lookup button clicked in form');
        lastClickTime = Date.now();
        modalShown = false;
        
        // Check for modal repeatedly
        checkForLookupModal();
        setTimeout(checkForLookupModal, 100);
        setTimeout(checkForLookupModal, 300);
        setTimeout(checkForLookupModal, 500);
        setTimeout(checkForLookupModal, 1000);
      }
    }, true);
    
    const checkForLookupModal = function() {
      const timeSince = Date.now() - lastClickTime;
      if (timeSince > 3000 || modalShown) return;
      
      console.log('🔍 Checking for lookup modal...');
      
      // Find lookup modals
      const lookupModals = document.querySelectorAll('.modal-lookup');
      console.log('Found', lookupModals.length, 'lookup modals');
      
      // Find one with show class
      let targetModal = null;
      for (let i = 0; i < lookupModals.length; i++) {
        const modal = lookupModals[i];
        if (modal.classList.contains('show')) {
          console.log('✅ Found lookup modal with show class');
          targetModal = modal;
          break;
        }
      }
      
      if (targetModal) {
        modalShown = true;
        forceLookupModalVisible(targetModal);
      } else {
        console.log('⏳ No lookup modal with show class yet');
      }
    };
    
    const forceLookupModalVisible = function(modal) {
      if (!modal) return;
      
      console.log('💪 Forcing lookup modal visible');
      
      // Remove fade
      modal.classList.remove('fade');
      
      // Force visibility
      modal.style.setProperty('display', 'flex', 'important');
      modal.style.setProperty('opacity', '1', 'important');
      modal.style.setProperty('visibility', 'visible', 'important');
      modal.style.setProperty('z-index', '10060', 'important');
      modal.style.setProperty('align-items', 'center', 'important');
      modal.style.setProperty('justify-content', 'center', 'important');
      
      // Add show class
      modal.classList.add('show');
      modal.removeAttribute('aria-hidden');
      modal.setAttribute('aria-modal', 'true');
      
      // Set modal-dialog width
      const modalDialog = modal.querySelector('.modal-dialog');
      if (modalDialog) {
        const screenWidth = window.innerWidth;
        const width = screenWidth >= 1400 ? '1400px' : '95%';
        
        modalDialog.style.setProperty('max-width', width, 'important');
        modalDialog.style.setProperty('width', width, 'important');
        modalDialog.style.setProperty('margin', '1.75rem auto', 'important');
        
        console.log('📐 Set lookup modal width:', width);
      }
      
      // Ensure backdrop exists for lookup modal
      const existingBackdrop = document.querySelector('.modal-backdrop.show');
      if (!existingBackdrop) {
        const backdrop = document.createElement('div');
        backdrop.className = 'modal-backdrop fade show';
        backdrop.style.cssText = 'position: fixed; top: 0; left: 0; width: 100%; height: 100%; background-color: rgba(0,0,0,0.5); z-index: 10059;';
        document.body.appendChild(backdrop);
        console.log('✅ Created lookup modal backdrop');
      }
      
      // Lock body
      if (!document.body.classList.contains('modal-open')) {
        document.body.classList.add('modal-open');
        document.body.style.overflow = 'hidden';
      }
      
      console.log('✅ Lookup modal forced visible');
    };
    
    console.log('✅ Lookup modal display handler initialized');
  };
  
  // ========================================
  // LOOKUP SELECTION HANDLER (FOR NESTED MODALS)
  // ========================================
  CS.initLookupSelectionHandler = function() {
    console.log('🟢 Initializing lookup selection handler');
    
    // Handle checkbox selection in lookup modal
    document.addEventListener('click', function(e) {
      const checkbox = e.target.closest('.modal-lookup .view-grid tbody .fa');
      
      if (checkbox) {
        console.log('✅ Checkbox clicked in nested lookup');
        
        const lookupModal = checkbox.closest('.modal-lookup');
        
        // Uncheck all checkboxes
        lookupModal.querySelectorAll('.view-grid tbody .fa').forEach(cb => {
          cb.setAttribute('aria-checked', 'false');
          cb.classList.remove('fa-check-square');
          cb.classList.add('fa-square-o');
        });
        
        // Check this one
        checkbox.setAttribute('aria-checked', 'true');
        checkbox.classList.remove('fa-square-o');
        checkbox.classList.add('fa-check-square');
        
        // Enable Select button
        const selectButton = lookupModal.querySelector('.btn.primary, .btn-primary');
        if (selectButton) {
          selectButton.removeAttribute('disabled');
        }
      }
    });
    
    // Handle Select button clicks
    document.addEventListener('click', function(e) {
      const selectButton = e.target.closest('.modal-lookup .btn.primary, .modal-lookup .btn-primary');
      
      if (selectButton && selectButton.textContent.trim() === 'Select') {
        console.log('✅ Select button clicked in nested lookup');
        
        const lookupModal = selectButton.closest('.modal-lookup');
        const checkedCheckbox = lookupModal.querySelector('.view-grid tbody .fa[aria-checked="true"]');
        
        if (!checkedCheckbox) {
          console.log('⚠️ No record selected');
          return;
        }
        
        const row = checkedCheckbox.closest('tr');
        const recordId = row.getAttribute('data-id');
        
        // Get record name from fullname column
        const nameCell = row.querySelector('td[data-attribute="fullname"]');
        let recordName = nameCell ? nameCell.textContent.trim() : '';
        
        // Fallback to email if no fullname
        if (!recordName) {
          const emailCell = row.querySelector('td[data-attribute="emailaddress1"]');
          recordName = emailCell ? emailCell.textContent.trim() : 'Selected Record';
        }
        
        console.log('📝 Selected:', recordName, recordId);
        
        // Find the field name from the lookup modal container
        const lookupModalContainer = lookupModal.closest('.lookup-modal');
        const entityLookup = lookupModalContainer ? lookupModalContainer.querySelector('.entity-lookup') : null;
        const fieldName = entityLookup ? entityLookup.getAttribute('data-lookup-datafieldname') : '';
        
        if (!fieldName || fieldName.trim() === '') {
          console.error('❌ Could not find field name');
          return;
        }
        
        console.log('🔍 Field name:', fieldName);
        
        // Populate the visible text field
        const lookupInput = document.querySelector(`input#${CSS.escape(fieldName)}_name`);
        const lookupHiddenInput = document.querySelector(`input#${CSS.escape(fieldName)}`);
        
        if (lookupInput && recordName) {
          lookupInput.value = recordName;
          console.log('✅ Populated visible field:', recordName);
          
          // Hide the placeholder dash
          const placeholder = lookupInput.parentElement.querySelector('.text-muted');
          if (placeholder) {
            placeholder.style.display = 'none';
          }
          
          if (lookupHiddenInput && recordId) {
            lookupHiddenInput.value = recordId;
            lookupHiddenInput.classList.add('dirty');
            console.log('✅ Populated hidden ID:', recordId);
          }
          
          // Trigger change events
          lookupInput.dispatchEvent(new Event('change', { bubbles: true }));
          if (lookupHiddenInput) {
            lookupHiddenInput.dispatchEvent(new Event('change', { bubbles: true }));
          }
          
          // Close the modal
          const closeButton = lookupModal.querySelector('[data-bs-dismiss="modal"], .close, .form-close');
          if (closeButton) {
            closeButton.click();
            console.log('✅ Modal closed');
          }
        } else {
          console.error('❌ Could not populate fields');
          console.log('lookupInput:', lookupInput);
          console.log('lookupHiddenInput:', lookupHiddenInput);
          console.log('recordName:', recordName);
        }
      }
    });
    
    console.log('✅ Lookup selection handler initialized');
  };
  
  // ========================================
  // RICH TEXT EDITOR
  // ========================================
  CS.initRichTextEditor = function(fieldName) {
    // Validate fieldName
    if (!fieldName || typeof fieldName !== 'string' || fieldName.trim() === '') {
      console.warn('⚠️ Invalid field name provided to initRichTextEditor:', fieldName);
      return;
    }
    
    console.log('🖊️ Initializing rich text editor for:', fieldName);
    
    // Wait for field to be available
    const waitForField = function(attempts) {
      attempts = attempts || 0;
      
      let textarea;
      try {
        textarea = document.querySelector(`#${CSS.escape(fieldName)}`);
      } catch (e) {
        console.error('⚠️ Invalid selector for field:', fieldName, e);
        return;
      }
      
      if (!textarea) {
        if (attempts < 20) {
          console.log(`⏳ Waiting for field ${fieldName}... (attempt ${attempts + 1})`);
          setTimeout(function() {
            waitForField(attempts + 1);
          }, 200);
          return;
        } else {
          console.log('⚠️ Field not found after 20 attempts:', fieldName);
          return;
        }
      }
      
      console.log('✅ Found field:', fieldName);
      
      // Hide textarea
      textarea.style.display = 'none';
      textarea.style.visibility = 'hidden';
      textarea.style.position = 'absolute';
      textarea.style.left = '-9999px';
      
      // Load Quill CSS
      if (!document.querySelector('link[href*="quill"]')) {
        const css = document.createElement('link');
        css.rel = 'stylesheet';
        css.href = 'https://cdn.quilljs.com/1.3.6/quill.snow.css';
        document.head.appendChild(css);
      }
      
      // Load Quill JS
      const loadQuill = function() {
        if (window.Quill) {
          initEditor();
        } else {
          const script = document.createElement('script');
          script.src = 'https://cdn.quilljs.com/1.3.6/quill.js';
          script.onload = initEditor;
          document.head.appendChild(script);
        }
      };
      
      const initEditor = function() {
        const editorDiv = document.createElement('div');
        editorDiv.id = `${fieldName}_editor`;
        editorDiv.style.minHeight = '200px';
        editorDiv.style.backgroundColor = 'white';
        editorDiv.style.border = '1px solid #ccc';
        editorDiv.style.borderRadius = '4px';
        textarea.parentNode.insertBefore(editorDiv, textarea);
        
        const quill = new Quill(`#${CSS.escape(fieldName)}_editor`, {
          theme: 'snow',
          placeholder: 'Enter text here...',
          modules: {
            toolbar: [
              [{ 'header': [1, 2, 3, false] }],
              ['bold', 'italic', 'underline'],
              [{ 'list': 'ordered'}, { 'list': 'bullet' }],
              ['link'],
              ['clean']
            ]
          }
        });
        
        if (textarea.value) quill.root.innerHTML = textarea.value;
        
        quill.on('text-change', function() {
          textarea.value = quill.root.innerHTML;
        });
        
        const form = textarea.closest('form');
        if (form) {
          form.addEventListener('submit', function() {
            textarea.value = quill.root.innerHTML;
          });
        }
        
        console.log('✅ Rich text editor initialized for:', fieldName);
      };
      
      loadQuill();
    };
    
    // Start waiting
    waitForField();
  };
  
  // ========================================
  // INITIALIZATION
  // ========================================
  CS.init = function(userConfig) {
    console.log('🚀 Initializing CS Basic Form Library v1.2');
    
    // Merge user config
    if (userConfig) {
      CS.config = Object.assign({}, CS.config, userConfig);
      if (userConfig.colors) {
        CS.config.colors = Object.assign({}, CS.config.colors, userConfig.colors);
      }
      if (userConfig.features) {
        CS.config.features = Object.assign({}, CS.config.features, userConfig.features);
      }
    }
    
    // Apply features immediately
    if (CS.config.features.lookupButtons || CS.config.features.calendarButtons || CS.config.features.submitButton) {
      CS.applyStyles();
    }
    
    if (CS.config.features.lookupButtons) {
      CS.cleanLookupButtons();
    }
    
    if (CS.config.features.lookupModals) {
      CS.initLookupModalFixes();
      CS.initLookupModalDisplay();
      CS.initLookupSelectionHandler();
    }
    
    // Rich text editors need to wait for DOM
    if (CS.config.features.richTextEditor && CS.config.richTextFields.length > 0) {
      setTimeout(function() {
        CS.config.richTextFields.forEach(function(fieldName) {
          CS.initRichTextEditor(fieldName);
        });
      }, 500);
    }
    
    console.log('✅ CS Basic Form Library initialized');
  };
  
})(window.CSBasicForm);