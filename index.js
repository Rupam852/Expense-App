// Grow Expense App - Landing Page Interactive Logic

document.addEventListener('DOMContentLoaded', () => {
  // 1. Navigation Scroll Effect
  const navbar = document.querySelector('.navbar');
  
  const handleScroll = () => {
    if (window.scrollY > 50) {
      navbar.classList.add('scrolled');
    } else {
      navbar.classList.remove('scrolled');
    }
  };

  window.addEventListener('scroll', handleScroll);
  // Run once initially to check scroll state
  handleScroll();

  // 2. Privacy Policy Modal Controls
  const privacyModal = document.getElementById('privacy-modal');
  const openPrivacyBtn = document.getElementById('open-privacy-btn');
  const openPrivacyFooter = document.getElementById('open-privacy-footer');
  const closePrivacyBtn = document.getElementById('close-privacy-btn');

  const openModal = () => {
    privacyModal.classList.add('active');
    document.body.style.overflow = 'hidden'; // Stop scrolling behind modal
  };

  const closeModal = () => {
    privacyModal.classList.remove('active');
    document.body.style.overflow = ''; // Restore scrolling
  };

  if (openPrivacyBtn) openPrivacyBtn.addEventListener('click', openModal);
  if (openPrivacyFooter) openPrivacyFooter.addEventListener('click', openModal);
  if (closePrivacyBtn) closePrivacyBtn.addEventListener('click', closeModal);

  // Close modal when clicking on overlay background
  privacyModal.addEventListener('click', (e) => {
    if (e.target === privacyModal) {
      closeModal();
    }
  });

  // Close modal with Escape key
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && privacyModal.classList.contains('active')) {
      closeModal();
    }
  });

  // 3. Feature Card Radial Spotlight Glow Effect
  const cards = document.querySelectorAll('.feature-card');
  
  cards.forEach(card => {
    card.addEventListener('mousemove', (e) => {
      const rect = card.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      
      card.style.setProperty('--mouse-x', `${x}px`);
      card.style.setProperty('--mouse-y', `${y}px`);
    });
  });

  // 4. Subtle Smooth Entrance Animation for timelines and lists
  const observeElements = document.querySelectorAll('.feature-card, .timeline-item');
  
  const observerOptions = {
    threshold: 0.1,
    rootMargin: '0px 0px -50px 0px'
  };

  const observer = new IntersectionObserver((entries, observer) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.style.opacity = '1';
        entry.target.style.transform = 'translateY(0)';
        observer.unobserve(entry.target);
      }
    });
  }, observerOptions);

  // Set initial hidden styles and observe
  observeElements.forEach(el => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(20px)';
    el.style.transition = 'opacity 0.6s ease-out, transform 0.6s cubic-bezier(0.16, 1, 0.3, 1)';
    observer.observe(el);
  });

  // 5. Scroll Progress Bar
  const scrollProgress = document.querySelector('.scroll-progress');
  window.addEventListener('scroll', () => {
    const totalScroll = document.documentElement.scrollHeight - window.innerHeight;
    if (totalScroll > 0) {
      const percentage = (window.scrollY / totalScroll) * 100;
      scrollProgress.style.width = `${percentage}%`;
    }
  });

  // 6. FAQ Accordion Toggle
  const faqItems = document.querySelectorAll('.faq-item');
  faqItems.forEach(item => {
    const question = item.querySelector('.faq-question');
    question.addEventListener('click', () => {
      // Close other active items
      faqItems.forEach(otherItem => {
        if (otherItem !== item && otherItem.classList.contains('active')) {
          otherItem.classList.remove('active');
          otherItem.style.maxHeight = null;
        }
      });
      // Toggle current item
      item.classList.toggle('active');
    });
  });
});
