/**
 * CYBER STRIKE - GameCMS Auth Page JS
 * Авторизация, регистрация, восстановление пароля
 */

// ==================== PRELOADER ====================
window.addEventListener('load', function() {
    const preloader = document.getElementById('auth-preloader');
    const video = document.getElementById('authBgVideo');
    
    setTimeout(() => {
        if (preloader) {
            preloader.classList.add('hidden');
        }
        if (video) {
            video.play().catch(e => console.log('Autoplay prevented:', e));
        }
        authCreateParticles();
    }, 2500);
});

// ==================== TAB SWITCHING ====================
const authTabs = document.querySelectorAll('.auth-tab');
const authTabContents = document.querySelectorAll('.auth-tab-content');
const authTabSwitches = document.querySelectorAll('.auth-tab-switch');

function authSwitchTab(tabName) {
    // Clear alerts
    authHideAlert();
    
    // Clear errors
    document.querySelectorAll('.auth-error-message').forEach(el => {
        el.classList.remove('show');
        el.textContent = '';
    });
    document.querySelectorAll('.auth-form-input').forEach(el => {
        el.classList.remove('error', 'success');
    });

    // Reset success messages
    const resetSuccess = document.getElementById('authResetSuccess');
    const resetForm = document.getElementById('authResetFormContainer');
    if (resetSuccess) resetSuccess.classList.remove('show');
    if (resetForm) resetForm.style.display = 'block';

    authTabs.forEach(tab => {
        tab.classList.remove('active');
        if (tab.dataset.tab === tabName) {
            tab.classList.add('active');
        }
    });

    authTabContents.forEach(content => {
        content.classList.remove('active');
        if (content.id === tabName) {
            content.classList.add('active');
        }
    });
}

authTabs.forEach(tab => {
    tab.addEventListener('click', () => {
        authSwitchTab(tab.dataset.tab);
    });
});

authTabSwitches.forEach(link => {
    link.addEventListener('click', (e) => {
        e.preventDefault();
        authSwitchTab(link.dataset.tab);
    });
});

// ==================== SOUND TOGGLE ====================
const authSoundToggle = document.getElementById('authSoundToggle');
const authVideo = document.getElementById('authBgVideo');
let authIsMuted = true;

if (authSoundToggle && authVideo) {
    authSoundToggle.addEventListener('click', () => {
        authIsMuted = !authIsMuted;
        authVideo.muted = authIsMuted;
        authSoundToggle.classList.toggle('muted', authIsMuted);
        authSoundToggle.innerHTML = authIsMuted ? '<i class="fas fa-volume-xmark"></i>' : '<i class="fas fa-volume-high"></i>';
    });
}

// ==================== PASSWORD TOGGLE ====================
document.querySelectorAll('.auth-password-toggle').forEach(btn => {
    btn.addEventListener('click', function() {
        const targetId = this.dataset.target;
        const input = document.getElementById(targetId);
        const icon = this.querySelector('i');
        
        if (input.type === 'password') {
            input.type = 'text';
            icon.classList.remove('fa-eye');
            icon.classList.add('fa-eye-slash');
        } else {
            input.type = 'password';
            icon.classList.remove('fa-eye-slash');
            icon.classList.add('fa-eye');
        }
    });
});

// ==================== PASSWORD STRENGTH ====================
const authRegPassword = document.getElementById('authRegPassword');
const authStrengthFill = document.getElementById('authStrengthFill');
const authStrengthText = document.getElementById('authStrengthText');

if (authRegPassword && authStrengthFill && authStrengthText) {
    authRegPassword.addEventListener('input', function() {
        const password = this.value;
        const strength = authCheckPasswordStrength(password);
        
        authStrengthFill.className = 'auth-strength-fill';
        authStrengthText.className = 'auth-strength-text';
        
        if (password.length === 0) {
            authStrengthText.textContent = 'Введите пароль';
        } else if (strength === 'weak') {
            authStrengthFill.classList.add('weak');
            authStrengthText.classList.add('weak');
            authStrengthText.textContent = 'Слабый пароль';
        } else if (strength === 'fair') {
            authStrengthFill.classList.add('fair');
            authStrengthText.classList.add('fair');
            authStrengthText.textContent = 'Средний пароль';
        } else if (strength === 'good') {
            authStrengthFill.classList.add('good');
            authStrengthText.classList.add('good');
            authStrengthText.textContent = 'Хороший пароль';
        } else if (strength === 'strong') {
            authStrengthFill.classList.add('strong');
            authStrengthText.classList.add('strong');
            authStrengthText.textContent = 'Отличный пароль!';
        }
    });
}

function authCheckPasswordStrength(password) {
    let score = 0;
    if (password.length >= 6) score++;
    if (password.length >= 10) score++;
    if (/[a-z]/.test(password) && /[A-Z]/.test(password)) score++;
    if (/\d/.test(password)) score++;
    if (/[^a-zA-Z0-9]/.test(password)) score++;
    
    if (score <= 1) return 'weak';
    if (score <= 2) return 'fair';
    if (score <= 3) return 'good';
    return 'strong';
}

// ==================== ALERT SYSTEM ====================
function authShowAlert(type, message) {
    const alert = document.getElementById('authAlert');
    const alertText = document.getElementById('authAlertText');
    const icon = alert.querySelector('i');
    
    alert.className = 'auth-alert show auth-alert-' + type;
    alertText.textContent = message;
    
    if (type === 'error') {
        icon.className = 'fas fa-exclamation-circle';
    } else if (type === 'success') {
        icon.className = 'fas fa-check-circle';
    } else if (type === 'warning') {
        icon.className = 'fas fa-exclamation-triangle';
    }

    // Auto hide after 5 seconds
    setTimeout(() => {
        authHideAlert();
    }, 5000);
}

function authHideAlert() {
    const alert = document.getElementById('authAlert');
    if (alert) {
        alert.classList.remove('show');
    }
}

// ==================== FORM VALIDATION ====================
function authShowError(inputId, message) {
    const input = document.getElementById(inputId);
    const error = document.getElementById(inputId + 'Error');
    if (input) {
        input.classList.add('error');
        input.classList.remove('success');
    }
    if (error) {
        error.textContent = message;
        error.classList.add('show');
    }
}

function authShowSuccess(inputId) {
    const input = document.getElementById(inputId);
    const error = document.getElementById(inputId + 'Error');
    if (input) {
        input.classList.remove('error');
        input.classList.add('success');
    }
    if (error) {
        error.classList.remove('show');
    }
}

function authClearValidation(inputId) {
    const input = document.getElementById(inputId);
    const error = document.getElementById(inputId + 'Error');
    if (input) {
        input.classList.remove('error', 'success');
    }
    if (error) {
        error.classList.remove('show');
    }
}

function authValidateEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function authValidateUsername(username) {
    return /^[a-zA-Z0-9_]{3,20}$/.test(username);
}

// ==================== LOGIN FORM ====================
const loginForm = document.getElementById('authLoginForm');
if (loginForm) {
    loginForm.addEventListener('submit', function(e) {
        e.preventDefault();
        let isValid = true;
        authHideAlert();

        const username = document.getElementById('authLoginUsername').value.trim();
        const password = document.getElementById('authLoginPassword').value;

        if (!username) {
            authShowError('authLoginUsername', 'Введите логин или email');
            isValid = false;
        } else {
            authShowSuccess('authLoginUsername');
        }

        if (!password) {
            authShowError('authLoginPassword', 'Введите пароль');
            isValid = false;
        } else if (password.length < 4) {
            authShowError('authLoginPassword', 'Минимум 4 символа');
            isValid = false;
        } else {
            authShowSuccess('authLoginPassword');
        }

        if (isValid) {
            const btn = this.querySelector('.auth-btn');
            btn.classList.add('auth-btn-loading');
            
            // Call GameCMS login function
            authUserLogin();
        }
    });
}

// GameCMS Login Integration
function authUserLogin() {
    const login = document.getElementById('authLoginUsername').value.trim();
    const password = document.getElementById('authLoginPassword').value;
    const token = document.getElementById('token').value;
    
    $.ajax({
        type: 'POST',
        url: '../ajax/actions.php',
        data: 'phpaction=1&token=' + token + '&user_login=1&login=' + encodeURIComponent(login) + '&password=' + encodeURIComponent(password),
        success: function(html) {
            const btn = document.querySelector('#authLoginForm .auth-btn');
            btn.classList.remove('auth-btn-loading');
            
            // Проверяем успешный вход (GameCMS возвращает reset_page())
            if (html.indexOf('reset_page()') !== -1) {
                authShowAlert('success', 'Добро пожаловать! Перенаправление...');
                setTimeout(() => {
                    window.location.href = '../';
                }, 1500);
            } else {
                // Извлекаем текст ошибки из HTML
                const errorMatch = html.match(/<p[^>]*class="text-danger"[^>]*>(.*?)<\/p>/);
                const errorText = errorMatch ? errorMatch[1] : 'Неверный логин или пароль';
                authShowAlert('error', errorText);
            }
        },
        error: function() {
            const btn = document.querySelector('#authLoginForm .auth-btn');
            btn.classList.remove('auth-btn-loading');
            authShowAlert('error', 'Ошибка соединения с сервером');
        }
    });
}

// ==================== REGISTER FORM ====================
const registerForm = document.getElementById('authRegisterForm');
if (registerForm) {
    registerForm.addEventListener('submit', function(e) {
        e.preventDefault();
        let isValid = true;
        authHideAlert();

        const username = document.getElementById('authRegUsername').value.trim();
        const email = document.getElementById('authRegEmail').value.trim();
        const password = document.getElementById('authRegPassword').value;
        const password2 = document.getElementById('authRegPassword2').value;
        const terms = document.getElementById('authTerms').checked;

        // Username validation
        if (!username) {
            authShowError('authRegUsername', 'Введите логин');
            isValid = false;
        } else if (!authValidateUsername(username)) {
            authShowError('authRegUsername', 'Только латиница, цифры и _ (3-20 символов)');
            isValid = false;
        } else {
            authShowSuccess('authRegUsername');
        }

        // Email validation
        if (!email) {
            authShowError('authRegEmail', 'Введите email');
            isValid = false;
        } else if (!authValidateEmail(email)) {
            authShowError('authRegEmail', 'Введите корректный email');
            isValid = false;
        } else {
            authShowSuccess('authRegEmail');
        }

        // Password validation
        if (!password) {
            authShowError('authRegPassword', 'Введите пароль');
            isValid = false;
        } else if (password.length < 6) {
            authShowError('authRegPassword', 'Минимум 6 символов');
            isValid = false;
        } else {
            authShowSuccess('authRegPassword');
        }

        // Password confirm
        if (!password2) {
            authShowError('authRegPassword2', 'Повторите пароль');
            isValid = false;
        } else if (password !== password2) {
            authShowError('authRegPassword2', 'Пароли не совпадают');
            isValid = false;
        } else {
            authShowSuccess('authRegPassword2');
        }

        // Terms
        if (!terms) {
            authShowAlert('warning', 'Необходимо согласиться с правилами');
            isValid = false;
        }

        if (isValid) {
            const btn = this.querySelector('.auth-btn');
            btn.classList.add('auth-btn-loading');
            
            // Call GameCMS registration function
            authUserRegister();
        }
    });
}

// GameCMS Registration Integration
function authUserRegister() {
    const login = document.getElementById('authRegUsername').value.trim();
    const email = document.getElementById('authRegEmail').value.trim();
    const password = document.getElementById('authRegPassword').value;
    const password2 = document.getElementById('authRegPassword2').value;
    const token = document.getElementById('token').value;
    
    // Get reCAPTCHA response if exists
    let captcha = '';
    if (typeof grecaptcha !== 'undefined') {
        captcha = grecaptcha.getResponse();
    }
    
    $.ajax({
        type: 'POST',
        url: '../ajax/actions.php',
        data: 'phpaction=1&token=' + token + '&registration=1&login=' + encodeURIComponent(login) + '&password=' + encodeURIComponent(password) + '&password2=' + encodeURIComponent(password2) + '&email=' + encodeURIComponent(email) + '&captcha=' + encodeURIComponent(captcha),
        success: function(html) {
            const btn = document.querySelector('#authRegisterForm .auth-btn');
            btn.classList.remove('auth-btn-loading');
            
            // Reset captcha
            if (typeof grecaptcha !== 'undefined') {
                grecaptcha.reset();
            }
            
            // Проверяем успешную регистрацию
            if (html.indexOf('text-success') !== -1) {
                const successMatch = html.match(/<p[^>]*class="text-success"[^>]*>(.*?)<\/p>/);
                const successText = successMatch ? successMatch[1] : 'Регистрация успешна!';
                authShowAlert('success', successText);
                setTimeout(() => {
                    authSwitchTab('login');
                }, 3000);
            } else {
                // Извлекаем текст ошибки из HTML
                const errorMatch = html.match(/<p[^>]*class="text-danger"[^>]*>(.*?)<\/p>/);
                const errorText = errorMatch ? errorMatch[1] : 'Ошибка регистрации';
                authShowAlert('error', errorText);
            }
        },
        error: function() {
            const btn = document.querySelector('#authRegisterForm .auth-btn');
            btn.classList.remove('auth-btn-loading');
            authShowAlert('error', 'Ошибка соединения с сервером');
        }
    });
}

// ==================== RESET FORM ====================
const resetForm = document.getElementById('authResetForm');
if (resetForm) {
    resetForm.addEventListener('submit', function(e) {
        e.preventDefault();
        let isValid = true;
        authHideAlert();

        const email = document.getElementById('authResetEmail').value.trim();

        if (!email) {
            authShowError('authResetEmail', 'Введите email');
            isValid = false;
        } else if (!authValidateEmail(email)) {
            authShowError('authResetEmail', 'Введите корректный email');
            isValid = false;
        } else {
            authShowSuccess('authResetEmail');
        }

        if (isValid) {
            const btn = this.querySelector('.auth-btn');
            btn.classList.add('auth-btn-loading');
            
            // Call GameCMS password reset function
            authPasswordReset();
        }
    });
}

// GameCMS Password Reset Integration
function authPasswordReset() {
    const email = document.getElementById('authResetEmail').value.trim();
    const token = document.getElementById('token').value;
    
    // Get reCAPTCHA response if exists
    let captcha = '';
    if (typeof grecaptcha !== 'undefined') {
        captcha = grecaptcha.getResponse();
    }
    
    $.ajax({
        type: 'POST',
        url: '../ajax/actions.php',
        data: 'phpaction=1&token=' + token + '&send_new_pass=1&email=' + encodeURIComponent(email) + '&captcha=' + encodeURIComponent(captcha),
        success: function(html) {
            const btn = document.querySelector('#authResetForm .auth-btn');
            btn.classList.remove('auth-btn-loading');
            
            // Reset captcha
            if (typeof grecaptcha !== 'undefined') {
                grecaptcha.reset();
            }
            
            // Проверяем успех (GameCMS всегда возвращает text-success для восстановления)
            if (html.indexOf('text-success') !== -1) {
                document.getElementById('authResetFormContainer').style.display = 'none';
                document.getElementById('authResetSuccess').classList.add('show');
            } else {
                // Извлекаем текст ошибки из HTML
                const errorMatch = html.match(/<p[^>]*class="text-danger"[^>]*>(.*?)<\/p>/);
                const errorText = errorMatch ? errorMatch[1] : 'Ошибка восстановления пароля';
                authShowAlert('error', errorText);
            }
        },
        error: function() {
            const btn = document.querySelector('#authResetForm .auth-btn');
            btn.classList.remove('auth-btn-loading');
            authShowAlert('error', 'Ошибка соединения с сервером');
        }
    });
}

// ==================== PARTICLES ====================
function authCreateParticles() {
    const particlesContainer = document.getElementById('auth-particles');
    if (!particlesContainer) return;
    
    const particleCount = 40;

    for (let i = 0; i < particleCount; i++) {
        const particle = document.createElement('div');
        particle.className = 'auth-particle';
        particle.style.left = Math.random() * 100 + '%';
        particle.style.animationDelay = Math.random() * 15 + 's';
        particle.style.animationDuration = (Math.random() * 10 + 15) + 's';
        particle.style.width = (Math.random() * 3 + 2) + 'px';
        particle.style.height = particle.style.width;
        particlesContainer.appendChild(particle);
    }
}

// ==================== REAL-TIME VALIDATION ====================
document.querySelectorAll('.auth-form-input').forEach(input => {
    input.addEventListener('blur', function() {
        if (this.value.trim() === '') {
            authClearValidation(this.id);
        }
    });
});

// ==================== VIDEO FALLBACK ====================
const bgVideo = document.getElementById('authBgVideo');
if (bgVideo) {
    bgVideo.addEventListener('error', () => {
        console.log('Video failed to load');
        const overlay = document.querySelector('.auth-video-overlay');
        if (overlay) {
            overlay.style.background = 'linear-gradient(135deg, #0a0a0f 0%, #1a1a25 50%, #0a0a0f 100%)';
        }
    });
}

// ==================== MODAL STYLES ====================
const modalStyles = `
<style>
.auth-modal {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.8);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 10001;
    backdrop-filter: blur(5px);
}

.auth-modal-content {
    background: var(--auth-card);
    border: 1px solid var(--auth-border);
    border-radius: 20px;
    width: 90%;
    max-width: 400px;
    overflow: hidden;
}

.auth-modal-header {
    padding: 20px 25px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.auth-modal-header h4 {
    font-family: 'Orbitron', sans-serif;
    font-size: 16px;
    font-weight: 700;
    margin: 0;
}

.auth-modal-close {
    background: none;
    border: none;
    color: var(--auth-text-muted);
    font-size: 18px;
    cursor: pointer;
    transition: color 0.3s ease;
}

.auth-modal-close:hover {
    color: var(--auth-cyan);
}

.auth-modal-body {
    padding: 25px;
}
</style>
`;
document.head.insertAdjacentHTML('beforeend', modalStyles);

// ==================== SERVER STATUS UPDATE ====================
function updateServerStatus() {
    const playersElement = document.getElementById('authPlayersOnline');
    if (playersElement) {
        let current = parseInt(playersElement.textContent) || 0;
        const target = Math.floor(Math.random() * 500) + 100;
        const step = (target - current) / 20;
        
        const interval = setInterval(() => {
            current += step;
            if ((step > 0 && current >= target) || (step < 0 && current <= target)) {
                current = target;
                clearInterval(interval);
            }
            playersElement.textContent = Math.round(current).toLocaleString();
        }, 50);
    }
}

setTimeout(updateServerStatus, 3000);

console.log('Auth page initialized');
