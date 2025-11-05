/**
 * Main JavaScript - SOLID Principles Applied
 * Single Responsibility: Each manager handles one specific concern
 * Open/Closed: Easy to extend with new managers without modifying existing code
 * Liskov Substitution: All managers are interchangeable
 * Interface Segregation: Clean, focused interfaces for each manager
 * Dependency Inversion: Depends on abstractions, not concrete implementations
 */

/**
 * Application Manager - Orchestrates all other managers
 * Single Responsibility: Manages application lifecycle and coordination
 */
class ApplicationManager {
    constructor() {
        this.managers = new Map();
        this.isInitialized = false;
    }

    /**
     * Initialize the application
     */
    async init() {
        if (this.isInitialized) {
            console.warn('Application already initialized');
            return;
        }

        try {
            // Initialize core managers
            await this.initializeManagers();
            
            // Setup global error handling
            this.setupErrorHandling();
            
            // Log successful initialization
            this.logInitialization();
            
            this.isInitialized = true;
        } catch (error) {
            console.error('Failed to initialize application:', error);
            throw error;
        }
    }

    /**
     * Initialize all managers
     */
    async initializeManagers() {
        // Theme Manager
        if (window.ThemeManager) {
            this.managers.set('theme', new window.ThemeManager());
        }

        // Navigation Manager
        if (window.NavigationManager) {
            this.managers.set('navigation', new window.NavigationManager());
        }

        // Animation Manager
        if (window.AnimationManager) {
            this.managers.set('animation', new window.AnimationManager());
        }
    }

    /**
     * Get a specific manager
     * @param {string} name - The manager name
     * @returns {Object|null} The manager instance or null
     */
    getManager(name) {
        return this.managers.get(name) || null;
    }

    /**
     * Setup global error handling
     */
    setupErrorHandling() {
        window.addEventListener('error', (event) => {
            console.error('Global error:', event.error);
        });

        window.addEventListener('unhandledrejection', (event) => {
            console.error('Unhandled promise rejection:', event.reason);
        });
    }

    /**
     * Log successful initialization
     */
    logInitialization() {
        console.log('🚀 BIT - Boks IT Support website loaded successfully!');
        console.log('📧 Contact: info@boksitsupport.ch');
        console.log('📞 Phone: +41 76 531 21 56');
        console.log('🎨 Theme Manager:', this.getManager('theme') ? '✅' : '❌');
        console.log('🧭 Navigation Manager:', this.getManager('navigation') ? '✅' : '❌');
        console.log('✨ Animation Manager:', this.getManager('animation') ? '✅' : '❌');
    }

    /**
     * Destroy the application
     */
    destroy() {
        this.managers.forEach(manager => {
            if (manager.destroy && typeof manager.destroy === 'function') {
                manager.destroy();
            }
        });
        this.managers.clear();
        this.isInitialized = false;
    }
}

/**
 * Utility functions
 * Single Responsibility: Each utility has one specific purpose
 */
const Utils = {
    /**
     * Debounce function calls
     * @param {Function} func - The function to debounce
     * @param {number} wait - The wait time in milliseconds
     * @returns {Function} The debounced function
     */
    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    },

    /**
     * Throttle function calls
     * @param {Function} func - The function to throttle
     * @param {number} limit - The time limit in milliseconds
     * @returns {Function} The throttled function
     */
    throttle(func, limit) {
        let inThrottle;
        return function(...args) {
            if (!inThrottle) {
                func.apply(this, args);
                inThrottle = true;
                setTimeout(() => inThrottle = false, limit);
            }
        };
    },

    /**
     * Check if element is in viewport
     * @param {Element} element - The element to check
     * @returns {boolean} True if element is in viewport
     */
    isInViewport(element) {
        const rect = element.getBoundingClientRect();
        return (
            rect.top >= 0 &&
            rect.left >= 0 &&
            rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) &&
            rect.right <= (window.innerWidth || document.documentElement.clientWidth)
        );
    },

    /**
     * Get element offset from top
     * @param {Element} element - The element
     * @returns {number} The offset from top
     */
    getOffsetTop(element) {
        let offsetTop = 0;
        do {
            if (!isNaN(element.offsetTop)) {
                offsetTop += element.offsetTop;
            }
        } while (element = element.offsetParent);
        return offsetTop;
    }
};

// Global application instance
let app;

/**
 * Initialize application when DOM is ready
 */
function initializeApp() {
    app = new ApplicationManager();
    app.init().catch(error => {
        console.error('Application initialization failed:', error);
    });
}

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeApp);
} else {
    initializeApp();
}

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        ApplicationManager,
        Utils
    };
}

// Make app globally available
window.app = app;
window.Utils = Utils;



