/**
 * Theme Manager - SOLID Principles Applied
 * Single Responsibility: Manages only theme-related functionality
 * Open/Closed: Easy to extend with new themes without modifying existing code
 * Liskov Substitution: All theme implementations are interchangeable
 * Interface Segregation: Clean, focused interface for theme operations
 * Dependency Inversion: Depends on abstractions, not concrete implementations
 */

class ThemeManager {
    constructor() {
        this.currentTheme = this.getStoredTheme() || 'light';
        this.themeToggle = null;
        this.body = document.body;
        this.init();
    }

    /**
     * Initialize the theme manager
     */
    init() {
        this.setupThemeToggle();
        this.applyTheme(this.currentTheme);
        this.setupEventListeners();
    }

    /**
     * Setup theme toggle button
     */
    setupThemeToggle() {
        this.themeToggle = document.getElementById('darkModeToggle');
        if (!this.themeToggle) {
            console.warn('Theme toggle button not found');
            return;
        }
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        if (this.themeToggle) {
            this.themeToggle.addEventListener('click', () => this.toggleTheme());
        }
    }

    /**
     * Get stored theme from localStorage
     * @returns {string|null} The stored theme or null
     */
    getStoredTheme() {
        try {
            return localStorage.getItem('theme');
        } catch (error) {
            console.warn('Could not access localStorage:', error);
            return null;
        }
    }

    /**
     * Store theme in localStorage
     * @param {string} theme - The theme to store
     */
    storeTheme(theme) {
        try {
            localStorage.setItem('theme', theme);
        } catch (error) {
            console.warn('Could not store theme in localStorage:', error);
        }
    }

    /**
     * Apply theme to the document
     * @param {string} theme - The theme to apply
     */
    applyTheme(theme) {
        this.body.setAttribute('data-theme', theme);
        this.updateThemeIcon(theme);
        this.currentTheme = theme;
    }

    /**
     * Update theme toggle icon
     * @param {string} theme - The current theme
     */
    updateThemeIcon(theme) {
        if (!this.themeToggle) return;

        const icon = this.themeToggle.querySelector('i');
        if (!icon) return;

        if (theme === 'dark') {
            icon.className = 'fas fa-sun';
        } else {
            icon.className = 'fas fa-moon';
        }
    }

    /**
     * Toggle between light and dark theme
     */
    toggleTheme() {
        const newTheme = this.currentTheme === 'dark' ? 'light' : 'dark';
        this.setTheme(newTheme);
    }

    /**
     * Set a specific theme
     * @param {string} theme - The theme to set
     */
    setTheme(theme) {
        if (theme !== 'light' && theme !== 'dark') {
            console.warn('Invalid theme:', theme);
            return;
        }

        this.applyTheme(theme);
        this.storeTheme(theme);
    }

    /**
     * Get current theme
     * @returns {string} The current theme
     */
    getCurrentTheme() {
        return this.currentTheme;
    }

    /**
     * Check if current theme is dark
     * @returns {boolean} True if dark theme is active
     */
    isDarkTheme() {
        return this.currentTheme === 'dark';
    }

    /**
     * Check if current theme is light
     * @returns {boolean} True if light theme is active
     */
    isLightTheme() {
        return this.currentTheme === 'light';
    }
}

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ThemeManager;
}

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.themeManager = new ThemeManager();
    });
} else {
    window.themeManager = new ThemeManager();
}

