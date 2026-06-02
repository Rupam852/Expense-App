async function check() {
  try {
    const res = await fetch('https://expense-tracker-backend-5pc1.onrender.com/expenses/debug-logs');
    const json = await res.json();
    console.log('RENDER DEBUG LOGS:', JSON.stringify(json, null, 2));
  } catch (err) {
    console.error('Fetch error:', err.message);
  }
}

check();
