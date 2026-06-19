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

  // 7. Global Mouse Tracking for Background Spotlight (GPU-Accelerated requestAnimationFrame)
  const spotlight = document.querySelector('.global-spotlight');
  if (spotlight) {
    let tick = false;
    document.addEventListener('mousemove', (e) => {
      if (!tick) {
        window.requestAnimationFrame(() => {
          // Center the 600px spotlight circle on the mouse position
          const x = e.clientX - 300;
          const y = e.clientY - 300;
          spotlight.style.transform = `translate3d(${x}px, ${y}px, 0)`;
          tick = false;
        });
        tick = true;
      }
    });
  }

  // 8. Hero Section Background Cyber Particles
  const heroParticlesContainer = document.querySelector('.hero-particles');
  if (heroParticlesContainer) {
    const particleCount = 15;
    for (let i = 0; i < particleCount; i++) {
      createParticle(heroParticlesContainer);
    }
  }

  function createParticle(container) {
    const particle = document.createElement('div');
    particle.classList.add('hero-particle');
    
    // Randomize initial properties
    const size = Math.random() * 6 + 3; // 3px to 9px
    const left = Math.random() * 100; // 0% to 100%
    const duration = Math.random() * 12 + 12; // 12s to 24s
    const delay = Math.random() * -24; // Staggered delay to make particles active immediately
    
    particle.style.width = `${size}px`;
    particle.style.height = `${size}px`;
    particle.style.left = `${left}%`;
    particle.style.animationDuration = `${duration}s`;
    particle.style.animationDelay = `${delay}s`;
    
    container.appendChild(particle);
  }

  // 9. Navbar Scroll Spy (Highlight active section)
  const spySections = document.querySelectorAll('section[id]');
  const navLinks = document.querySelectorAll('.nav-links a[href^="#"]');
  
  const spyObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const id = entry.target.getAttribute('id');
        navLinks.forEach(link => {
          const href = link.getAttribute('href').substring(1);
          if (href === id) {
            link.classList.add('active');
          } else {
            link.classList.remove('active');
          }
        });
      }
    });
  }, {
    threshold: 0.2,
    rootMargin: '-80px 0px -40% 0px'
  });
  
  spySections.forEach(section => {
    if (section.getAttribute('id')) {
      spyObserver.observe(section);
    }
  });

  // 10. Back to Top Button visibility & action
  const backToTopBtn = document.getElementById('back-to-top');
  if (backToTopBtn) {
    let scrollTick = false;
    window.addEventListener('scroll', () => {
      if (!scrollTick) {
        window.requestAnimationFrame(() => {
          if (window.scrollY > 400) {
            backToTopBtn.classList.add('visible');
          } else {
            backToTopBtn.classList.remove('visible');
          }
          scrollTick = false;
        });
        scrollTick = true;
      }
    });
    backToTopBtn.addEventListener('click', () => {
      window.scrollTo({
        top: 0,
        behavior: 'smooth'
      });
    });
  }

  // 11. Testimonials Carousel Controller
  const testimonialCards = document.querySelectorAll('.testimonial-card');
  const testimonialDots = document.querySelectorAll('.carousel-dots .dot');
  const prevBtn = document.getElementById('carousel-prev');
  const nextBtn = document.getElementById('carousel-next');
  let currentSlide = 0;
  let autoplayInterval;

  const showSlide = (index) => {
    testimonialCards.forEach((card, i) => {
      if (i === index) {
        card.classList.add('active');
      } else {
        card.classList.remove('active');
      }
    });

    testimonialDots.forEach((dot, i) => {
      if (i === index) {
        dot.classList.add('active');
      } else {
        dot.classList.remove('active');
      }
    });

    currentSlide = index;
  };

  const nextSlide = () => {
    let next = currentSlide + 1;
    if (next >= testimonialCards.length) {
      next = 0;
    }
    showSlide(next);
  };

  const prevSlide = () => {
    let prev = currentSlide - 1;
    if (prev < 0) {
      prev = testimonialCards.length - 1;
    }
    showSlide(prev);
  };

  const startAutoplay = () => {
    stopAutoplay();
    autoplayInterval = setInterval(nextSlide, 6000);
  };

  const stopAutoplay = () => {
    if (autoplayInterval) {
      clearInterval(autoplayInterval);
    }
  };

  const resetAutoplay = () => {
    stopAutoplay();
    startAutoplay();
  };

  if (nextBtn) {
    nextBtn.addEventListener('click', () => {
      nextSlide();
      resetAutoplay();
    });
  }

  if (prevBtn) {
    prevBtn.addEventListener('click', () => {
      prevSlide();
      resetAutoplay();
    });
  }

  testimonialDots.forEach((dot, index) => {
    dot.addEventListener('click', () => {
      showSlide(index);
      resetAutoplay();
    });
  });

  if (testimonialCards.length > 0) {
    startAutoplay();
  }

  // 12. Web Audio Haptic Synthesizer
  let audioCtx = null;
  const initAudio = () => {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
  };

  const playHaptic = (type = 'click') => {
    try {
      initAudio();
      if (!audioCtx || audioCtx.state === 'suspended') return;
      
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      
      if (type === 'click') {
        osc.frequency.setValueAtTime(600, audioCtx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(150, audioCtx.currentTime + 0.015);
        gain.gain.setValueAtTime(0.04, audioCtx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.015);
        osc.start();
        osc.stop(audioCtx.currentTime + 0.015);
      } else if (type === 'double') {
        osc.frequency.setValueAtTime(450, audioCtx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(120, audioCtx.currentTime + 0.02);
        gain.gain.setValueAtTime(0.03, audioCtx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.02);
        osc.start();
        osc.stop(audioCtx.currentTime + 0.02);
      } else if (type === 'beep') {
        osc.type = 'sine';
        osc.frequency.setValueAtTime(880, audioCtx.currentTime);
        gain.gain.setValueAtTime(0.02, audioCtx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.08);
        osc.start();
        osc.stop(audioCtx.currentTime + 0.08);
      } else if (type === 'success') {
        osc.frequency.setValueAtTime(523.25, audioCtx.currentTime); // C5
        osc.frequency.exponentialRampToValueAtTime(1046.50, audioCtx.currentTime + 0.06); // C6
        gain.gain.setValueAtTime(0.03, audioCtx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.06);
        osc.start();
        osc.stop(audioCtx.currentTime + 0.06);
      }
    } catch (e) {
      // Audio context failed / browser blocked autoplay
    }
  };

  document.addEventListener('click', initAudio, { once: true });
  document.addEventListener('touchstart', initAudio, { once: true });

  const interactableButtons = document.querySelectorAll('.download-btn, .download-btn-small, .download-btn-large, .learn-more-btn, .sim-btn, .control-btn, #sim-fab-btn');
  interactableButtons.forEach(btn => {
    btn.addEventListener('mouseenter', () => playHaptic('click'));
    btn.addEventListener('click', () => playHaptic('double'));
  });

  // 13. Mobile App Simulator Interactive Logic
  let simSpentTotal = 893.26;
  let simRecordsCount = 12;

  const simSpentTotalEl = document.getElementById('sim-spent-total');
  const simRecordsCountEl = document.getElementById('sim-records-count');
  const simTxListEl = document.getElementById('sim-tx-list');
  const simScanOverlay = document.getElementById('sim-scan-overlay');
  const simSyncOverlay = document.getElementById('sim-sync-overlay');
  const simSyncTextOverlay = document.getElementById('sim-sync-text-overlay');
  const simCloudIcon = document.getElementById('sim-cloud-icon');
  const simSyncTrigger = document.getElementById('sim-sync-trigger');

  const formatCurrency = (val) => {
    return '₹' + val.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  };

  const updateSimUI = () => {
    if (simSpentTotalEl) simSpentTotalEl.textContent = formatCurrency(simSpentTotal);
    if (simRecordsCountEl) simRecordsCountEl.textContent = simRecordsCount + ' Records';
  };

  const addManualExpense = () => {
    const manualExpenses = [
      { merchant: 'Tea Stall Chai', category: 'Food & dining', amount: 10.00, emoji: '🍕', iconType: 'food' },
      { merchant: 'Lunch Thali Meal', category: 'Food & dining', amount: 120.00, emoji: '🍕', iconType: 'food' },
      { merchant: 'Mobile Recharge', category: 'Services', amount: 399.00, emoji: '💼', iconType: 'services' },
      { merchant: 'Stationery Notebooks', category: 'Others', amount: 85.00, emoji: '🛒', iconType: 'other' }
    ];
    
    const randomItem = manualExpenses[Math.floor(Math.random() * manualExpenses.length)];
    addSimTransaction(randomItem.merchant, randomItem.amount, randomItem.category, randomItem.iconType);
  };

  const addScanExpense = () => {
    if (!simScanOverlay) return;
    simScanOverlay.classList.add('active');
    
    let beepInterval = setInterval(() => playHaptic('beep'), 600);
    
    setTimeout(() => {
      clearInterval(beepInterval);
      simScanOverlay.classList.remove('active');
      
      const scanExpenses = [
        { merchant: 'McDonalds Burger Deal', category: 'Food & dining', amount: 320.00, iconType: 'food' },
        { merchant: 'Zudio T-Shirt', category: 'Shopping', amount: 499.00, iconType: 'other' },
        { merchant: 'Auto Fare Ride', category: 'Services', amount: 90.00, iconType: 'services' },
        { merchant: 'Medicines Apollo', category: 'Services', amount: 180.00, iconType: 'services' }
      ];
      
      const randomItem = scanExpenses[Math.floor(Math.random() * scanExpenses.length)];
      addSimTransaction(randomItem.merchant, randomItem.amount, randomItem.category, randomItem.iconType);
      playHaptic('success');
    }, 2500);
  };

  const addSimTransaction = (merchant, amount, category, iconType) => {
    if (!simTxListEl) return;
    simSpentTotal += amount;
    simRecordsCount += 1;
    
    const newTx = document.createElement('div');
    newTx.className = 'sim-tx-item';
    
    let iconHTML = '';
    let bgClass = 'bg-orange-dim';
    
    if (iconType === 'services') {
      bgClass = 'bg-blue-dim';
      iconHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class="sim-category-svg" style="color: #3b82f6;"><rect x="2" y="7" width="20" height="14" rx="2" ry="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/></svg>`;
    } else if (iconType === 'food') {
      bgClass = 'bg-orange-dim';
      iconHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class="sim-category-svg" style="color: #f97316;"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>`;
    } else {
      bgClass = 'bg-purple-dim';
      iconHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" class="sim-category-svg" style="color: #a78bfa;"><rect x="2" y="4" width="20" height="16" rx="2" ry="2"/><line x1="12" y1="4" x2="12" y2="20"/></svg>`;
    }
    
    newTx.innerHTML = `
      <span class="sim-tx-category-icon ${bgClass}">
        ${iconHTML}
      </span>
      <div class="sim-tx-details">
        <h4 class="sim-tx-merchant">${merchant}</h4>
        <span class="sim-tx-date">${category} • Today</span>
      </div>
      <span class="sim-tx-value">₹${amount.toFixed(2)}</span>
    `;
    
    if (simTxListEl.children.length >= 4) {
      simTxListEl.removeChild(simTxListEl.lastElementChild);
    }
    simTxListEl.insertBefore(newTx, simTxListEl.firstChild);
    
    if (simCloudIcon && simSyncTrigger) {
      simSyncTrigger.classList.add('syncing');
      simCloudIcon.style.color = '#ef4444'; // Red/orange alert color for unsynced changes
    }
    
    updateSimUI();
  };

  const syncSimDatabase = () => {
    if (!simSyncOverlay) return;
    simSyncOverlay.classList.add('active');
    if (simSyncTrigger && simCloudIcon) {
      simSyncTrigger.classList.add('syncing');
      simCloudIcon.style.color = '#fbbf24'; // Yellow for syncing
    }
    
    const steps = [
      'Encrypting SQLite sandbox...',
      'Opening secure Supabase tunnel...',
      'Merging transaction branches...',
      'Reconciliation complete!'
    ];
    
    let currentStep = 0;
    const interval = setInterval(() => {
      if (currentStep < steps.length) {
        if (simSyncTextOverlay) simSyncTextOverlay.textContent = steps[currentStep];
        playHaptic('click');
        currentStep++;
      } else {
        clearInterval(interval);
        simSyncOverlay.classList.remove('active');
        
        if (simSyncTrigger && simCloudIcon) {
          simSyncTrigger.classList.remove('syncing');
          simCloudIcon.style.color = ''; // Reset to green
        }
        playHaptic('success');
      }
    }, 600);
  };

  const btnScan = document.getElementById('sim-action-scan');
  const btnAdd = document.getElementById('sim-action-add');
  const btnSync = document.getElementById('sim-action-sync');
  const simFabBtn = document.getElementById('sim-fab-btn');

  if (btnScan) btnScan.addEventListener('click', addScanExpense);
  if (btnAdd) btnAdd.addEventListener('click', addManualExpense);
  if (btnSync) btnSync.addEventListener('click', syncSimDatabase);
  if (simSyncTrigger) simSyncTrigger.addEventListener('click', syncSimDatabase);
  if (simFabBtn) simFabBtn.addEventListener('click', addManualExpense);

  // 14. 3D Card Hover Tilt Micro-Interactions
  const bentoCards = document.querySelectorAll('.bento-card');
  bentoCards.forEach(card => {
    card.addEventListener('mousemove', (e) => {
      const rect = card.getBoundingClientRect();
      const x = e.clientX - rect.left - rect.width / 2;
      const y = e.clientY - rect.top - rect.height / 2;
      
      const rotateX = -y / 15;
      const rotateY = x / 15;
      
      card.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale3d(1.02, 1.02, 1.02)`;
    });
    
    card.addEventListener('mouseleave', () => {
      card.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg) scale3d(1, 1, 1)';
    });
  });

  // 15. Savings Projection Calculator Widget Logic
  const incomeSlider = document.getElementById('income-slider');
  const expenseSlider = document.getElementById('expense-slider');
  const incomeValEl = document.getElementById('income-val');
  const expenseValEl = document.getElementById('expense-val');
  const monthlySavingsVal = document.getElementById('monthly-savings-val');
  const savingsRatioBadge = document.getElementById('savings-ratio-badge');
  const year1Val = document.getElementById('year-1-val');
  const year3Val = document.getElementById('year-3-val');
  const spendingRatioLabel = document.getElementById('spending-ratio-label');
  const savingsRatioLabel = document.getElementById('savings-ratio-label');
  const ratioSpendingFill = document.getElementById('ratio-spending-fill');
  const ratioSavingsFill = document.getElementById('ratio-savings-fill');

  const formatRupee = (val) => {
    return '₹' + val.toLocaleString('en-IN');
  };

  const calculateProjections = () => {
    if (!incomeSlider || !expenseSlider) return;
    let income = parseInt(incomeSlider.value);
    let expenses = parseInt(expenseSlider.value);
    
    if (expenses > income) {
      expenses = income;
      expenseSlider.value = income;
    }
    
    if (incomeValEl) incomeValEl.textContent = formatRupee(income);
    if (expenseValEl) expenseValEl.textContent = formatRupee(expenses);
    
    const savings = income - expenses;
    if (monthlySavingsVal) monthlySavingsVal.textContent = formatRupee(savings);
    
    const spendingPercent = income > 0 ? Math.round((expenses / income) * 100) : 0;
    const savingsPercent = 100 - spendingPercent;
    
    if (savingsRatioBadge) savingsRatioBadge.textContent = savingsPercent + '% Saved';
    if (spendingRatioLabel) spendingRatioLabel.textContent = `Spending (${spendingPercent}%)`;
    if (savingsRatioLabel) savingsRatioLabel.textContent = `Savings (${savingsPercent}%)`;
    
    if (ratioSpendingFill) ratioSpendingFill.style.width = spendingPercent + '%';
    if (ratioSavingsFill) ratioSavingsFill.style.width = savingsPercent + '%';
    
    const year1 = savings * 12;
    if (year1Val) year1Val.textContent = formatRupee(year1);
    
    const rate = 0.12 / 12;
    const months = 36;
    let year3Compounded = 0;
    if (savings > 0) {
      year3Compounded = savings * ((Math.pow(1 + rate, months) - 1) / rate) * (1 + rate);
    }
    
    if (year3Val) year3Val.textContent = formatRupee(Math.round(year3Compounded));
    playHaptic('click');
  };

  if (incomeSlider && expenseSlider) {
    incomeSlider.addEventListener('input', calculateProjections);
    expenseSlider.addEventListener('input', calculateProjections);
    calculateProjections();
  }
});