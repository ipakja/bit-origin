/**
 * Animation Manager - SOLID Principles Applied
 * Single Responsibility: Manages only animation-related functionality
 * Open/Closed: Easy to extend with new animations without modifying existing code
 * Liskov Substitution: All animation implementations are interchangeable
 * Interface Segregation: Clean, focused interface for animation operations
 * Dependency Inversion: Depends on abstractions, not concrete implementations
 */

class AnimationManager {
    constructor() {
        this.observer = null;
        this.animatedElements = new Set();
        this.init();
    }

    /**
     * Initialize the animation manager
     */
    init() {
        this.setupIntersectionObserver();
        this.observeElements();
    }

    /**
     * Setup intersection observer for scroll animations
     */
    setupIntersectionObserver() {
        const observerOptions = {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        };

        this.observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    this.animateElement(entry.target);
                }
            });
        }, observerOptions);
    }

    /**
     * Observe elements for animation
     */
    observeElements() {
        const selectors = [
            '.service-card',
            '.package-card',
            '.expertise-category',
            '.human-factor-content',
            '.cta-content',
            '.why-content'
        ];

        selectors.forEach(selector => {
            const elements = document.querySelectorAll(selector);
            elements.forEach(element => {
                this.observeElement(element);
            });
        });
    }

    /**
     * Observe a specific element
     * @param {Element} element - The element to observe
     */
    observeElement(element) {
        if (this.observer && !this.animatedElements.has(element)) {
            this.observer.observe(element);
            this.animatedElements.add(element);
        }
    }

    /**
     * Animate an element
     * @param {Element} element - The element to animate
     */
    animateElement(element) {
        // Add fade-in animation
        element.classList.add('animate-fade-in-up');
        
        // Remove from observer to prevent re-animation
        if (this.observer) {
            this.observer.unobserve(element);
        }
    }

    /**
     * Add animation to element
     * @param {Element} element - The element to animate
     * @param {string} animationClass - The animation class to add
     */
    addAnimation(element, animationClass) {
        if (element && animationClass) {
            element.classList.add(animationClass);
        }
    }

    /**
     * Remove animation from element
     * @param {Element} element - The element to remove animation from
     * @param {string} animationClass - The animation class to remove
     */
    removeAnimation(element, animationClass) {
        if (element && animationClass) {
            element.classList.remove(animationClass);
        }
    }

    /**
     * Check if element is animated
     * @param {Element} element - The element to check
     * @returns {boolean} True if element is animated
     */
    isAnimated(element) {
        return this.animatedElements.has(element);
    }

    /**
     * Get all animated elements
     * @returns {Set} Set of animated elements
     */
    getAnimatedElements() {
        return new Set(this.animatedElements);
    }

    /**
     * Reset all animations
     */
    resetAnimations() {
        this.animatedElements.forEach(element => {
            element.classList.remove('animate-fade-in-up');
        });
        this.animatedElements.clear();
        this.observeElements();
    }

    /**
     * Destroy the animation manager
     */
    destroy() {
        if (this.observer) {
            this.observer.disconnect();
            this.observer = null;
        }
        this.animatedElements.clear();
    }
}

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = AnimationManager;
}

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        window.animationManager = new AnimationManager();
    });
} else {
    window.animationManager = new AnimationManager();
}

