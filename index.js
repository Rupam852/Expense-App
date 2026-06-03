// Grow Expense App - Rebuilt Custom Interactive Logic

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
  handleScroll();

  // 2. Privacy Policy Modal Controls
  const privacyModal = document.getElementById('privacy-modal');
  const openPrivacyBtn = document.getElementById('open-privacy-btn');
  const openPrivacyFooter = document.getElementById('open-privacy-footer');
  const closePrivacyBtn = document.getElementById('close-privacy-btn');

  const openModal = () => {
    privacyModal.classList.add('active');
    document.body.style.overflow = 'hidden';
  };

  const closeModal = () => {
    privacyModal.classList.remove('active');
    document.body.style.overflow = '';
  };

  if (openPrivacyBtn) openPrivacyBtn.addEventListener('click', openModal);
  if (openPrivacyFooter) openPrivacyFooter.addEventListener('click', openModal);
  if (closePrivacyBtn) closePrivacyBtn.addEventListener('click', closeModal);

  privacyModal.addEventListener('click', (e) => {
    if (e.target === privacyModal) {
      closeModal();
    }
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && privacyModal.classList.contains('active')) {
      closeModal();
    }
  });

  // 3. Bento Card Radial Spotlight Glow Effect
  const cards = document.querySelectorAll('.bento-card');
  
  cards.forEach(card => {
    card.addEventListener('mousemove', (e) => {
      const rect = card.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      
      card.style.setProperty('--mouse-x', `${x}px`);
      card.style.setProperty('--mouse-y', `${y}px`);
    });
  });

  // 4. Subtle Smooth Entrance Scroll Animation
  const observeElements = document.querySelectorAll('.bento-card, .timeline-item, .calc-card');
  
  const observerOptions = {
    threshold: 0.05,
    rootMargin: '0px 0px -40px 0px'
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

  observeElements.forEach(el => {
    el.style.opacity = '0';
    el.style.transform = 'translateY(25px)';
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
      faqItems.forEach(otherItem => {
        if (otherItem !== item && otherItem.classList.contains('active')) {
          otherItem.classList.remove('active');
        }
      });
      item.classList.toggle('active');
    });
  });

  // 7. Interactive Budget Planner Calculator Slider
  const slider = document.getElementById('income-slider');
  const incomeVal = document.getElementById('income-val');
  const budgetVal = document.getElementById('budget-val');
  const savingsVal = document.getElementById('savings-val');
  const wantsVal = document.getElementById('wants-val');

  if (slider) {
    slider.addEventListener('input', (e) => {
      const val = parseInt(e.target.value);
      incomeVal.textContent = `₹${val.toLocaleString('en-IN')}`;
      budgetVal.textContent = `₹${(val * 0.5).toLocaleString('en-IN')}`;
      savingsVal.textContent = `₹${(val * 0.3).toLocaleString('en-IN')}`;
      wantsVal.textContent = `₹${(val * 0.2).toLocaleString('en-IN')}`;
    });
  }
});
