/**
 * Navigation Manager - SOLID Principles Applied
 * Single Responsibility: Manages only navigation-related functionality
 * Open/Closed: Easy to extend with new navigation features
 * Liskov Substitution: All navigation implementations are interchangeable
 * Interface Segregation: Clean, focused interface for navigation operations
 * Dependency Inversion: Depends on abstractions, not concrete implementations
 */

class NavigationManager {
    constructor() {
        this.mobileMenuToggle = null;
        this.mobileNav = null;
        this.header = null;
        this.navLinks = [];
        this.init();
    }

    /**
     * Initialize the navigation manager
     */
    init() {
        this.setupElements();
        this.setupEventListeners();
        this.setupScrollEffects();
    }

    /**
     * Setup DOM elements
     */
    setupElements() {
        this.mobileMenuToggle = document.getElementById('mobileMenuToggle');
        this.mobileNav = document.getElementById('mobileNav');
        this.header = document.getElementById('header');
        this.navLinks = document.querySelectorAll('.nav-links a, .mobile-nav-links a');
    }

    /**
     * Setup event listeners
     */
    setupEventListeners() {
        // Mobile menu toggle
        if (this.mobileMenuToggle) {
            this.mobileMenuToggle.addEventListener('click', () => this.toggleMobileMenu());
        }

        // Close mobile menu when clicking on links
        this.navLinks.forEach(link => {
            link.addEventListener('click', () => this.closeMobileMenu());
        });

        // Close mobile menu when clicking outside
        document.addEventListener('click', (event) => this.handleOutsideClick(event));

        // Smooth scrolling for anchor links
        this.setupSmoothScrolling();
    }

    /**
     * Setup scroll effects
     */
    setupScrollEffects() {
        if (!this.header) return;

        window.addEventListener('scroll', () => {
            this.handleScroll();
        });
    }

    /**
     * Handle scroll events
     */
    handleScroll() {
        if (window.scrollY > 100) {
            this.header.classList.add('scrolled');
        } else {
            this.header.classList.remove('scrolled');
        }
    }

    /**
     * Toggle mobile menu
     */
    toggleMobileMenu() {
        if (!this.mobileMenuToggle || !this.mobileNav) return;

        this.mobileMenuToggle.classList.toggle('active');
        this.mobileNav.classList.toggle('active');
    }

    /**
     * Close mobile menu
     */
    closeMobileMenu() {
        if (!this.mobileMenuToggle || !this.mobileNav) return;

        this.mobileMenuToggle.classList.remove('active');
        this.mobileNav.classList.remove('active');
    }

    /**
     * Handle clicks outside mobile menu
     * @param {Event} event - The click event
     */
    handleOutsideClick(event) {
        if (!this.mobileMenuToggle || !this.mobileNav) return;

        const isClickInsideMenu = this.mobileMenuToggle.contains(event.target) || 
                                 this.mobileNav.contains(event.target);

        if (!isClickInsideMenu) {
            this.closeMobileMenu();
        }
    }

    /**
     * Setup smooth scrolling for anchor links
     */
    setupSmoothScrolling() {
        const anchorLinks = document.querySelectorAll('a[href^="#"]');
        
        anchorLinks.forEach(anchor => {
            anchor.addEventListener('click', (e) => {
                e.preventDefault();
                const target = document.querySelector(anchor.getAttribute('href'));
                
                if (target) {
                    this.smoothScrollTo(target);
                }
            });
        });
    }

    /**
     * Smooth scroll to target element
     * @param {Element} target - The target element
     */
    smoothScrollTo(target) {
        target.scrollIntoView({
            behavior: 'smooth',
            block: 'start'
        });
    }

    /**
     * Get current mobile menu state
     * @returns {boolean} True if mobile menu is open
     */
    isMobileMenuOpen() {
        return this.mobileNav && this.mobileNav.classList.contains('active');
    }

    /**
     * Set mobile menu state
     * @param {boolean} isOpen - Whether to open or close the menu
     */
    setMobileMenuState(isOpen) {
        if (!this.mobileMenuToggle || !this.mobileNav) return;

        if (isOpen) {
            this.mobileMenuToggle.classList.add('active');
            this.mobileNav.classList.add('active');
        } else {
            this.mobileMenuToggle.classList.remove('active');
            this.mobileNav.classList.remove('active');
        }
    }
}

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = NavigationManager;
}

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.navigationManager = new NavigationManager();
    });
} else {
    window.navigationManager = new NavigationManager();
}

