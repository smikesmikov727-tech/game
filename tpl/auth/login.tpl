{include file="config.tpl"}
{if($user)}
<script>window.location.href = '{site_host}';</script>
{/if}
{if($auth)}
<script>window.location.href = '{site_host}';</script>
{/if}
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="utf-8">
    <title>Авторизация | {site_name}</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Orbitron:wght@400;500;600;700;800;900&family=Rajdhani:wght@300;400;500;600;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
    <link rel="shortcut icon" href="{site_host}templates/{template}/img/favicon.ico">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        :root{--cyan:#00f0ff;--magenta:#ff00aa;--green:#00ff88;--dark:#0a0a0f;--darker:#050508;--card:rgba(15,15,22,0.95);--border:rgba(0,240,255,0.2);--text:#fff;--text2:#a0a0b0;--muted:#6a6a7a;--success:#00ff88;--danger:#ff4444;--warning:#ffcc00}
        html,body{width:100%;height:100%;font-family:'Rajdhani',sans-serif;background:var(--darker);color:var(--text);overflow:hidden;-webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale}
        #preloader{position:fixed;top:0;left:0;width:100%;height:100%;background:#0a0a0f;display:flex;flex-direction:column;justify-content:center;align-items:center;z-index:10000;transition:opacity .5s,visibility .5s;will-change:opacity}
        #preloader.hidden{opacity:0;visibility:hidden;pointer-events:none}
        .preloader-logo{font-family:'Orbitron',sans-serif;font-size:clamp(2.5rem,6vw,4rem);font-weight:900;letter-spacing:8px;color:#ffcc00;text-shadow:0 0 20px #ffcc00;animation:neonPulse 2s ease-in-out infinite;margin-bottom:2rem;will-change:text-shadow}
        .loader{width:80px;height:80px;position:relative}
        .loader-ring{position:absolute;width:100%;height:100%;border:3px solid transparent;border-top-color:#ffcc00;border-radius:50%;animation:spin 1s linear infinite;will-change:transform;transform:translateZ(0)}
        .loader-ring:nth-child(2){width:70%;height:70%;top:15%;left:15%;border-top-color:#ff9500;animation-delay:-.2s;animation-direction:reverse}
        .loader-ring:nth-child(3){width:50%;height:50%;top:25%;left:25%;border-top-color:#ff6600;animation-delay:-.4s}
        .loading-text{margin-top:2rem;font-family:'Share Tech Mono',monospace;font-size:.9rem;color:var(--text2);letter-spacing:4px;text-transform:uppercase}
        .loading-progress{width:250px;height:3px;background:rgba(255,255,255,.08);border-radius:10px;margin-top:1rem;overflow:hidden}
        .loading-bar{height:100%;background:#ffcc00;border-radius:10px;width:0;animation:load 2s ease-out forwards;will-change:width}
        .video-bg{position:fixed;top:0;left:0;width:100%;height:100%;z-index:0;overflow:hidden;background:var(--darker);contain:strict}
        .video-bg video{position:absolute;top:50%;left:50%;min-width:100%;min-height:100%;width:auto;height:auto;transform:translate(-50%,-50%) translateZ(0);object-fit:cover}
        .video-overlay{position:fixed;top:0;left:0;width:100%;height:100%;background:linear-gradient(135deg,rgba(10,10,15,.85),rgba(5,5,8,.8));z-index:1;contain:strict}
        .scanlines{position:fixed;top:0;left:0;width:100%;height:100%;background:repeating-linear-gradient(0deg,rgba(0,0,0,.02) 0px,rgba(0,0,0,.02) 1px,transparent 1px,transparent 2px);pointer-events:none;z-index:1001;opacity:.4;contain:strict}
        #particles{position:fixed;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:2;overflow:hidden;contain:strict}
        .particle{position:absolute;bottom:-20px;width:4px;height:4px;background:var(--cyan);border-radius:50%;opacity:0;animation:float 20s linear infinite;will-change:transform,opacity;transform:translateZ(0)}
        .particle:nth-child(odd){background:var(--magenta)}
        .particle:nth-child(3n){background:var(--green)}
        .sound-btn{position:fixed;bottom:30px;right:30px;width:50px;height:50px;background:var(--card);border:1px solid var(--border);border-radius:50%;display:flex;justify-content:center;align-items:center;cursor:pointer;z-index:100;transition:transform .2s;color:var(--cyan);font-size:18px;contain:layout}
        .sound-btn:hover{transform:scale(1.1)}
        .sound-btn.muted{color:var(--muted)}
        .container{position:fixed;top:0;left:0;width:100%;height:100%;display:flex;justify-content:center;align-items:center;padding:20px;z-index:10;overflow:hidden;contain:layout}
        .wrapper{width:100%;max-width:480px;animation:fadeUp .5s ease-out;max-height:calc(100vh - 40px);overflow-y:auto;overflow-x:hidden;scrollbar-width:none;-ms-overflow-style:none;contain:content}
        .wrapper::-webkit-scrollbar{display:none}
        .logo-section{text-align:center;margin-bottom:40px;padding:0 10px}
        .logo{display:inline-flex;flex-direction:column;align-items:center;gap:15px;text-decoration:none;max-width:100%}
        .logo-icon{width:80px;height:80px;background:linear-gradient(135deg,#ffcc00,#00f0ff,#ff00aa);border-radius:20px;display:flex;align-items:center;justify-content:center;font-size:36px;color:#fff;position:relative;animation:pulse 3s ease-in-out infinite;box-shadow:0 0 20px rgba(255,204,0,.3)}
        .logo-icon::before{content:'';position:absolute;inset:3px;background:var(--dark);border-radius:17px;z-index:0}
        .logo-icon i{position:relative;z-index:1}
        .logo-text{font-family:'Orbitron',sans-serif;font-weight:900;font-size:clamp(14px,2.5vw,24px);letter-spacing:clamp(1px,0.3vw,4px);background:linear-gradient(90deg,#ffcc00,#00f0ff,#ff00aa);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;text-align:center;line-height:1.3;word-wrap:break-word;max-width:100%}
        .logo-sub{font-family:'Share Tech Mono',monospace;font-size:11px;letter-spacing:4px;text-transform:uppercase;background:linear-gradient(90deg,#ffcc00,#00f0ff,#ff00aa);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}
        .card{background:rgba(15,15,22,0.98);border:1px solid rgba(255,204,0,.2);border-radius:20px;padding:40px;position:relative;overflow:hidden;contain:content}
        .card::before{content:'';position:absolute;top:0;left:0;right:0;height:3px;background:linear-gradient(90deg,#ffcc00,#00f0ff,#ff00aa,#00ff88,#ffcc00);animation:glow 3s linear infinite;background-size:200% 100%;will-change:background-position}
        .card::after{content:'';position:absolute;top:15px;right:15px;width:60px;height:60px;border-top:2px solid rgba(255,204,0,.4);border-right:2px solid rgba(255,204,0,.4);border-radius:0 10px 0 0;pointer-events:none}
        .corner{position:absolute;bottom:15px;left:15px;width:60px;height:60px;border-bottom:2px solid rgba(255,204,0,.4);border-left:2px solid rgba(255,204,0,.4);border-radius:0 0 0 10px;pointer-events:none}
        .tabs{display:flex;gap:5px;margin-bottom:30px;background:rgba(255,255,255,.03);padding:5px;border-radius:12px;border:1px solid rgba(255,204,0,.2)}
        .tab{flex:1;padding:14px 20px;background:transparent;border:none;border-radius:10px;font-family:'Rajdhani',sans-serif;font-weight:600;font-size:14px;letter-spacing:1px;text-transform:uppercase;color:var(--muted);cursor:pointer;transition:color .2s,background .2s}
        .tab span{display:inline-block}
        .tab:hover{color:#ffcc00}
        .tab:hover span{color:#ffcc00}
        .tab.active{background:linear-gradient(135deg,rgba(255,204,0,.15),rgba(0,240,255,.1))}
        .tab.active span{background:linear-gradient(90deg,#ffcc00,#00f0ff,#ff00aa,#00ff88,#ffcc00);background-size:200% 100%;-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;animation:textGlow 3s linear infinite;will-change:background-position}
        .tab-content{display:none}
        .tab-content.active{display:block}
        .form-group{margin-bottom:20px}
        .form-label{display:block;font-weight:600;font-size:12px;letter-spacing:2px;text-transform:uppercase;color:var(--text2);margin-bottom:10px}
        .input-wrap{position:relative}
        .input-icon{position:absolute;left:18px;top:50%;transform:translateY(-50%);color:var(--muted);font-size:16px;z-index:2}
        .form-input{width:100%;padding:16px 50px 16px 50px;background:rgba(255,255,255,.03);border:1px solid rgba(255,204,0,.4);border-radius:12px;font-family:'Rajdhani',sans-serif;font-size:15px;color:var(--text);transition:border-color .2s,background .2s}
        .form-input::placeholder{color:var(--muted)}
        .form-input:focus{outline:none;border-color:#ffcc00;background:rgba(255,204,0,.05);color:#ffcc00}
        .pass-toggle{position:absolute;right:18px;top:50%;transform:translateY(-50%);background:none;border:none;color:var(--muted);cursor:pointer;font-size:16px;z-index:2}
        .pass-toggle:hover{color:#ffcc00}
        .checkbox-row{display:flex;justify-content:space-between;align-items:center;margin-bottom:25px;flex-wrap:wrap;gap:10px}
        .checkbox-group{display:flex;align-items:center;gap:10px;cursor:pointer}
        .checkbox-group input{display:none}
        .checkbox-custom{width:20px;height:20px;background:rgba(255,255,255,.05);border:1px solid rgba(255,204,0,.4);border-radius:6px;display:flex;align-items:center;justify-content:center;transition:background .2s,border-color .2s;color:transparent;font-size:11px}
        .checkbox-group input:checked+.checkbox-custom{background:#ffcc00;border-color:#ffcc00;color:var(--dark)}
        .checkbox-group span:last-child{font-size:13px;color:var(--text2)}
        .form-link{font-size:13px;color:var(--cyan);text-decoration:none;transition:color .2s}
        .form-link:hover{color:var(--magenta)}
        .btn{width:100%;padding:18px 30px;border:3px solid transparent;border-radius:12px;font-family:'Rajdhani',sans-serif;font-weight:700;font-size:15px;letter-spacing:2px;text-transform:uppercase;cursor:pointer;transition:transform .2s;position:relative;background:linear-gradient(var(--dark),var(--dark)) padding-box,linear-gradient(90deg,#ffcc00,#00f0ff,#ff00aa,#00ff88,#ffcc00) border-box;background-size:100% 100%,300% 100%;color:var(--cyan);animation:btnBorderGlow 3s linear infinite;will-change:background-position}
        .btn:hover{transform:translateY(-2px)}
        .btn.loading{pointer-events:none}
        .btn.loading .btn-text{visibility:hidden}
        .btn.loading::after{content:'';position:absolute;width:20px;height:20px;top:50%;left:50%;margin:-10px 0 0 -10px;border:2px solid transparent;border-top-color:var(--cyan);border-radius:50%;animation:spin .6s linear infinite;will-change:transform}
        @keyframes btnBorderGlow{0%{background-position:0% 0%,0% 50%}100%{background-position:0% 0%,300% 50%}}
        .divider{display:flex;align-items:center;gap:15px;margin:25px 0;color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:2px}
        .divider::before,.divider::after{content:'';flex:1;height:1px;background:rgba(255,255,255,.1)}
        .social-btns{display:flex;gap:12px}
        .social-btn{flex:1;padding:14px;background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.08);border-radius:12px;display:flex;align-items:center;justify-content:center;gap:10px;font-family:'Rajdhani',sans-serif;font-weight:600;font-size:13px;color:var(--text2);cursor:pointer;transition:background .2s,border-color .2s,color .2s;text-decoration:none}
        .social-btn i{font-size:18px}
        .social-btn.vk:hover{background:rgba(0,119,255,.15);border-color:#0077ff;color:#0077ff}
        .social-btn.steam:hover{background:rgba(23,26,33,.5);border-color:#66c0f4;color:#66c0f4}
        .footer-text{text-align:center;margin-top:25px;padding-top:25px;border-top:1px solid rgba(255,255,255,.05);font-size:14px;color:var(--text2)}
        .footer-text a{color:var(--cyan);text-decoration:none;font-weight:600;cursor:pointer}
        .footer-text a:hover{color:var(--magenta)}
        .success-msg{display:none;text-align:center;padding:30px}
        .success-msg.show{display:block}
        .success-icon{width:80px;height:80px;background:linear-gradient(135deg,rgba(0,255,136,.2),rgba(0,255,136,.1));border:2px solid var(--success);border-radius:50%;display:flex;align-items:center;justify-content:center;margin:0 auto 20px;font-size:36px;color:var(--success)}
        .success-title{font-family:'Orbitron',sans-serif;font-size:20px;font-weight:700;margin-bottom:10px;color:var(--success)}
        .success-text{color:var(--text2);margin-bottom:25px}
        .result{margin-bottom:15px;padding:15px 18px;border-radius:12px;font-family:'Share Tech Mono',monospace;font-size:13px;letter-spacing:1px;display:none;position:relative;overflow:hidden}
        .result::before{content:'';position:absolute;top:0;left:0;width:100%;height:2px;background:linear-gradient(90deg,transparent,currentColor,transparent);animation:resultGlow 2s linear infinite}
        .result::after{content:'';position:absolute;top:0;right:0;width:30px;height:30px;border-top:2px solid currentColor;border-right:2px solid currentColor;opacity:.3;border-radius:0 10px 0 0}
        .result.show{display:flex;align-items:center;gap:12px;animation:resultSlide .4s ease-out}
        .result.error{background:linear-gradient(135deg,rgba(255,68,68,.15),rgba(255,0,100,.1));border:1px solid rgba(255,68,68,.4);color:#ff6b6b;box-shadow:0 0 20px rgba(255,68,68,.2),inset 0 0 30px rgba(255,68,68,.05);text-shadow:0 0 10px rgba(255,68,68,.5)}
        .result.success{background:linear-gradient(135deg,rgba(0,255,136,.15),rgba(0,200,100,.1));border:1px solid rgba(0,255,136,.4);color:#00ff88;box-shadow:0 0 20px rgba(0,255,136,.2),inset 0 0 30px rgba(0,255,136,.05);text-shadow:0 0 10px rgba(0,255,136,.5)}
        .result i.result-icon{font-size:18px;animation:resultPulse 1.5s ease-in-out infinite}
        @keyframes resultSlide{from{opacity:0;transform:translateY(-10px)}to{opacity:1;transform:translateY(0)}}
        @keyframes resultGlow{0%,100%{opacity:.3}50%{opacity:.8}}
        @keyframes resultPulse{0%,100%{transform:scale(1)}50%{transform:scale(1.1)}}
        .strength{margin-top:10px}
        .strength-bar{height:4px;background:rgba(255,255,255,.1);border-radius:2px;overflow:hidden;margin-bottom:8px}
        .strength-fill{height:100%;width:0;transition:all .3s;border-radius:2px}
        .strength-fill.weak{width:25%;background:var(--danger)}
        .strength-fill.fair{width:50%;background:var(--warning)}
        .strength-fill.good{width:75%;background:var(--cyan)}
        .strength-fill.strong{width:100%;background:var(--success)}
        .strength-text{font-size:11px;color:var(--muted)}
        .strength-text.weak{color:var(--danger)}
        .strength-text.fair{color:var(--warning)}
        .strength-text.good{color:var(--cyan)}
        .strength-text.strong{color:var(--success)}
        .captcha-wrap{margin-bottom:20px;transform:scale(0.9);transform-origin:0 0}
        .modal-overlay{display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,.8);z-index:10001;justify-content:center;align-items:center}
        .modal-overlay.show{display:flex}
        .modal-box{background:var(--card);border:1px solid var(--border);border-radius:20px;width:90%;max-width:400px;padding:30px}
        .modal-title{font-family:'Orbitron',sans-serif;font-size:18px;margin-bottom:20px;color:var(--cyan)}
        .modal-close{background:transparent;border:1px solid var(--border);color:var(--text2);margin-top:10px}
        
        /* CYBER ALERT POPUP */
        .cyber-popup-overlay{display:none;position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,.9);z-index:10002;justify-content:center;align-items:center;backdrop-filter:blur(10px)}
        .cyber-popup-overlay.show{display:flex;animation:fadeIn .3s ease}
        .cyber-popup{background:linear-gradient(135deg,rgba(15,15,22,.98),rgba(20,20,30,.98));border:2px solid var(--warning);border-radius:20px;width:90%;max-width:420px;padding:0;position:relative;overflow:hidden;box-shadow:0 0 40px rgba(255,204,0,.3),0 0 80px rgba(255,204,0,.1),inset 0 0 60px rgba(255,204,0,.05);animation:popupSlide .4s ease}
        .cyber-popup::before{content:'';position:absolute;top:0;left:0;right:0;height:3px;background:linear-gradient(90deg,transparent,var(--warning),var(--cyan),var(--warning),transparent);animation:popupGlow 2s linear infinite}
        .cyber-popup::after{content:'⚠';position:absolute;top:-30px;left:50%;transform:translateX(-50%);font-size:60px;opacity:.1;filter:blur(2px)}
        .cyber-popup-corner-tl{position:absolute;top:10px;left:10px;width:30px;height:30px;border-top:2px solid var(--warning);border-left:2px solid var(--warning);border-radius:5px 0 0 0;opacity:.5}
        .cyber-popup-corner-tr{position:absolute;top:10px;right:10px;width:30px;height:30px;border-top:2px solid var(--warning);border-right:2px solid var(--warning);border-radius:0 5px 0 0;opacity:.5}
        .cyber-popup-corner-bl{position:absolute;bottom:10px;left:10px;width:30px;height:30px;border-bottom:2px solid var(--warning);border-left:2px solid var(--warning);border-radius:0 0 0 5px;opacity:.5}
        .cyber-popup-corner-br{position:absolute;bottom:10px;right:10px;width:30px;height:30px;border-bottom:2px solid var(--warning);border-right:2px solid var(--warning);border-radius:0 0 5px 0;opacity:.5}
        .cyber-popup-header{padding:25px 30px 20px;text-align:center;border-bottom:1px solid rgba(255,204,0,.2)}
        .cyber-popup-icon{width:70px;height:70px;margin:0 auto 15px;background:linear-gradient(135deg,rgba(255,204,0,.2),rgba(255,150,0,.1));border:2px solid var(--warning);border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:32px;color:var(--warning);animation:iconPulse 2s ease-in-out infinite;box-shadow:0 0 30px rgba(255,204,0,.3)}
        .cyber-popup-title{font-family:'Orbitron',sans-serif;font-size:18px;font-weight:700;color:var(--warning);text-transform:uppercase;letter-spacing:3px;margin:0;text-shadow:0 0 20px rgba(255,204,0,.5)}
        .cyber-popup-body{padding:25px 30px}
        .cyber-popup-text{font-family:'Rajdhani',sans-serif;font-size:15px;color:var(--text2);line-height:1.7;text-align:center;margin-bottom:20px}
        .cyber-popup-text strong{color:var(--cyan);font-weight:600}
        .cyber-popup-hint{background:rgba(0,240,255,.1);border:1px solid rgba(0,240,255,.2);border-radius:10px;padding:15px;margin-bottom:20px}
        .cyber-popup-hint p{font-family:'Share Tech Mono',monospace;font-size:12px;color:var(--cyan);margin:0;display:flex;align-items:center;gap:10px}
        .cyber-popup-hint i{font-size:16px}
        .cyber-popup-btn{width:100%;padding:15px 25px;border:none;border-radius:12px;font-family:'Rajdhani',sans-serif;font-weight:700;font-size:14px;letter-spacing:2px;text-transform:uppercase;cursor:pointer;transition:all .3s;background:linear-gradient(135deg,var(--warning),#ff9500);color:var(--dark);box-shadow:0 0 20px rgba(255,204,0,.3)}
        .cyber-popup-btn:hover{transform:translateY(-2px);box-shadow:0 0 30px rgba(255,204,0,.5)}
        .cyber-popup-close{position:absolute;top:15px;right:15px;width:30px;height:30px;background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.1);border-radius:8px;display:flex;align-items:center;justify-content:center;cursor:pointer;color:var(--muted);font-size:14px;transition:all .3s;z-index:10}
        .cyber-popup-close:hover{background:rgba(255,68,68,.2);border-color:var(--danger);color:var(--danger)}
        @keyframes popupSlide{from{opacity:0;transform:scale(.9) translateY(-20px)}to{opacity:1;transform:scale(1) translateY(0)}}
        @keyframes popupGlow{0%,100%{background-position:-200% 0}50%{background-position:200% 0}}
        @keyframes iconPulse{0%,100%{transform:scale(1);box-shadow:0 0 30px rgba(255,204,0,.3)}50%{transform:scale(1.05);box-shadow:0 0 40px rgba(255,204,0,.5)}}
        
        @keyframes grad{0%,100%{background-position:0 50%}50%{background-position:100% 50%}}
        @keyframes neonPulse{0%,100%{text-shadow:0 0 20px #ffcc00,0 0 40px #ff9500}50%{text-shadow:0 0 30px #ffcc00,0 0 60px #ff9500}}
        @keyframes spin{from{transform:rotate(0)}to{transform:rotate(360deg)}}
        @keyframes load{0%{width:0}100%{width:100%}}
        @keyframes float{0%{transform:translateY(0) translateX(0);opacity:0}10%{opacity:.6}90%{opacity:.6}100%{transform:translateY(-100vh) translateX(20px);opacity:0}}
        @keyframes fadeIn{from{opacity:0}to{opacity:1}}
        @keyframes fadeUp{from{opacity:0;transform:translateY(30px)}to{opacity:1;transform:translateY(0)}}
        @keyframes pulse{0%,100%{transform:scale(1)}50%{transform:scale(1.02)}}
        @keyframes glow{0%{background-position:0 50%}100%{background-position:200% 50%}}
        @keyframes textGlow{0%{background-position:0% 50%}100%{background-position:200% 50%}}
        
        /* Мобильная оптимизация */
        @media(max-width:540px){
            .card{padding:20px 12px}
            .card::after,.corner{display:none}
            .logo-section{margin-bottom:15px}
            .logo-icon{width:40px;height:40px;font-size:18px;animation:none;border-radius:12px}
            .logo-icon::before{border-radius:10px}
            .logo-sub{font-size:8px;letter-spacing:1px}
            .logo{gap:8px}
            .tabs{margin-bottom:15px;padding:3px}
            .tab{padding:8px 5px;font-size:9px;letter-spacing:0}
            .social-btns{flex-direction:column;gap:8px}
            .social-btn{padding:10px}
            .form-group{margin-bottom:10px}
            .form-label{font-size:10px;margin-bottom:6px;letter-spacing:1px}
            .form-input{padding:10px 40px;font-size:13px;border-radius:8px}
            .input-icon{left:14px;font-size:14px}
            .pass-toggle{right:14px;font-size:14px}
            .btn{padding:12px 15px;font-size:12px;border-radius:8px;animation:none;border:2px solid #ffcc00}
            .divider{margin:15px 0;font-size:10px}
            .container{padding:5px}
            .wrapper{max-width:100%;max-height:calc(100vh - 10px);animation:none;padding:5px}
            .checkbox-row{margin-bottom:15px}
            .checkbox-custom{width:16px;height:16px}
            .checkbox-group span:last-child{font-size:11px}
            .form-link{font-size:11px}
            .strength{margin-top:5px}
            .strength-fill{height:2px}
            .strength-text{font-size:9px}
            /* Оптимизация прелоадера */
            .preloader-logo{font-size:clamp(1.5rem,8vw,2.5rem);letter-spacing:4px;text-shadow:0 0 10px #ffcc00;animation:none}
            .loader-ring{animation:spin .8s linear infinite}
            .loader-ring:nth-child(2){animation:spin .8s linear infinite reverse}
            .loader-ring:nth-child(3){animation:spin .8s linear infinite}
            /* Отключаем тяжёлые эффекты, но видео оставляем */
            .particle{display:none}
            .scanlines{display:none}
            .card::before{animation:none;background:#ffcc00;height:2px}
            .tab.active span{animation:none;color:#ffcc00;-webkit-text-fill-color:#ffcc00}
        }
        @media(max-width:380px){
            .tab{font-size:8px;padding:6px 4px}
            .tabs{gap:2px;padding:2px}
            .card{padding:15px 10px}
            .form-input{padding:8px 35px;font-size:12px}
            .btn{padding:10px 12px;font-size:11px}
            .logo-icon{width:35px;height:35px;font-size:16px}
        }
    </style>
</head>
<body>
    <input type="hidden" id="token" value="{token}">
    
    <div id="preloader">
        <div class="preloader-logo">CS-ZONE.RU</div>
        <div class="loader"><div class="loader-ring"></div><div class="loader-ring"></div><div class="loader-ring"></div></div>
        <div class="loading-text">Инициализация системы...</div>
        <div class="loading-progress"><div class="loading-bar"></div></div>
    </div>
    
    <div class="video-bg">
        <video id="bgVideo" autoplay muted loop playsinline>
            <source src="{site_host}templates/{template}/video/back_video.mp4" type="video/mp4">
        </video>
    </div>
    <div class="video-overlay"></div>
    <div class="scanlines"></div>
    <div id="particles"></div>
    
    <button class="sound-btn muted" id="soundBtn"><i class="fas fa-volume-xmark"></i></button>
    
    <div class="container">
        <div class="wrapper">
            <div class="logo-section">
                <a href="{site_host}" class="logo">
                    <div class="logo-icon"><i class="fas fa-crosshairs"></i></div>
                    <span class="logo-text">{site_name}</span>
                    <span class="logo-sub">Game Community Portal</span>
                </a>
            </div>
            
            <div class="card">
                <div class="corner"></div>
                
                <div class="tabs">
                    <button class="tab active" data-tab="login"><span><i class="fas fa-right-to-bracket"></i> Вход</span></button>
                    <button class="tab" data-tab="register"><span><i class="fas fa-user-plus"></i> Регистрация</span></button>
                    <button class="tab" data-tab="reset"><span><i class="fas fa-key"></i> Сброс</span></button>
                </div>
                
                <div class="tab-content active" id="login">
                    <form id="loginForm">
                        <div class="form-group">
                            <label class="form-label">Логин или Email</label>
                            <div class="input-wrap">
                                <input type="text" class="form-input" id="login_user" placeholder="Введите логин или email" maxlength="30">
                                <i class="fas fa-user input-icon"></i>
                            </div>
                        </div>
                        <div class="form-group">
                            <label class="form-label">Пароль</label>
                            <div class="input-wrap">
                                <input type="password" class="form-input" id="login_pass" placeholder="Введите пароль" maxlength="15">
                                <i class="fas fa-lock input-icon"></i>
                                <button type="button" class="pass-toggle" onclick="togglePass('login_pass', this)"><i class="fas fa-eye"></i></button>
                            </div>
                        </div>
                        <div class="checkbox-row">
                            <label class="checkbox-group">
                                <input type="checkbox" id="remember_me">
                                <span class="checkbox-custom"><i class="fas fa-check"></i></span>
                                <span>Запомнить меня</span>
                            </label>
                            <a href="#" class="form-link" onclick="switchTab('reset'); return false;">Забыли пароль?</a>
                        </div>
                        <div class="result" id="loginResult"></div>
                        <button type="submit" class="btn" id="loginBtn"><span class="btn-text">Войти в систему</span></button>
                    </form>
                    
                    {if($auth_api->vk_api == 1 || $auth_api->steam_api == 1)}
                    <div class="divider">или войдите через</div>
                    <div class="social-btns">
                        {if($auth_api->vk_api == 1)}
                        <a href="#" onclick="oAuthLogin('vk'); return false;" class="social-btn vk"><i class="fab fa-vk"></i> VK</a>
                        {/if}
                        {if($auth_api->steam_api == 1)}
                        <a href="#" onclick="oAuthLogin('steam'); return false;" class="social-btn steam"><i class="fab fa-steam"></i> Steam</a>
                        {/if}
                    </div>
                    {/if}
                    
                    <div class="footer-text">Нет аккаунта? <a onclick="switchTab('register'); return false;">Зарегистрируйтесь</a></div>
                </div>
                
                <div class="tab-content" id="register">
                    {if($conf->standard_registration)}
                    <form id="regForm">
                        <div class="form-group">
                            <label class="form-label">Логин</label>
                            <div class="input-wrap">
                                <input type="text" class="form-input" id="reg_login" placeholder="Придумайте логин" maxlength="30">
                                <i class="fas fa-user input-icon"></i>
                            </div>
                        </div>
                        <div class="form-group">
                            <label class="form-label">Email</label>
                            <div class="input-wrap">
                                <input type="email" class="form-input" id="reg_email" placeholder="Введите email" maxlength="255">
                                <i class="fas fa-envelope input-icon"></i>
                            </div>
                        </div>
                        <div class="form-group">
                            <label class="form-label">Пароль</label>
                            <div class="input-wrap">
                                <input type="password" class="form-input" id="reg_password" placeholder="Придумайте пароль" maxlength="15">
                                <i class="fas fa-lock input-icon"></i>
                                <button type="button" class="pass-toggle" onclick="togglePass('reg_password', this)"><i class="fas fa-eye"></i></button>
                            </div>
                            <div class="strength">
                                <div class="strength-bar"><div class="strength-fill" id="strengthFill"></div></div>
                                <span class="strength-text" id="strengthText">Введите пароль</span>
                            </div>
                        </div>
                        <div class="form-group">
                            <label class="form-label">Повторите пароль</label>
                            <div class="input-wrap">
                                <input type="password" class="form-input" id="reg_password2" placeholder="Повторите пароль" maxlength="15">
                                <i class="fas fa-lock input-icon"></i>
                                <button type="button" class="pass-toggle" onclick="togglePass('reg_password2', this)"><i class="fas fa-eye"></i></button>
                            </div>
                        </div>
                        
                        {if($conf->privacy_policy == 1)}
                        <div class="checkbox-row">
                            <label class="checkbox-group">
                                <input type="checkbox" id="privacy_check">
                                <span class="checkbox-custom"><i class="fas fa-check"></i></span>
                                <span>Согласен с <a href="{site_host}processing-of-personal-data" target="_blank" class="form-link">правилами</a></span>
                            </label>
                        </div>
                        {/if}
                        
                        {if($conf->captcha != '2')}
                        <div class="captcha-wrap">
                            <div class="g-recaptcha" data-theme="dark" data-sitekey="{$conf->captcha_client_key}"></div>
                        </div>
                        {/if}
                        
                        <div class="result" id="regResult"></div>
                        <button type="submit" class="btn" id="regBtn"><span class="btn-text">Создать аккаунт</span></button>
                    </form>
                    {else}
                    <p style="text-align:center;color:var(--text2);padding:40px 0">Стандартная регистрация отключена</p>
                    {/if}
                    
                    {if($auth_api->vk_api == 1 || $auth_api->steam_api == 1)}
                    <div class="divider">или через соцсети</div>
                    <div class="social-btns">
                        {if($auth_api->vk_api == 1)}
                        <a href="#" class="social-btn vk" onclick="showApiModal('vk'); return false;"><i class="fab fa-vk"></i> VK</a>
                        {/if}
                        {if($auth_api->steam_api == 1)}
                        <a href="#" class="social-btn steam" onclick="showApiModal('steam'); return false;"><i class="fab fa-steam"></i> Steam</a>
                        {/if}
                    </div>
                    {/if}
                    
                    <div class="footer-text">Уже есть аккаунт? <a onclick="switchTab('login'); return false;">Войдите</a></div>
                </div>
                
                <div class="tab-content" id="reset">
                    <div id="resetFormWrap">
                        <form id="resetForm">
                            <div class="form-group">
                                <label class="form-label">Email</label>
                                <div class="input-wrap">
                                    <input type="email" class="form-input" id="reset_email" placeholder="Введите ваш email" maxlength="255">
                                    <i class="fas fa-envelope input-icon"></i>
                                </div>
                            </div>
                            <p style="color:var(--text2);font-size:13px;margin-bottom:25px"><i class="fas fa-info-circle" style="color:var(--cyan);margin-right:8px"></i>Мы отправим инструкции на указанный email</p>
                            <div class="result" id="resetResult"></div>
                            <button type="submit" class="btn" id="resetBtn"><span class="btn-text">Восстановить пароль</span></button>
                        </form>
                        <div class="footer-text">Вспомнили пароль? <a onclick="switchTab('login'); return false;">Войдите</a></div>
                    </div>
                    <div class="success-msg" id="resetSuccess">
                        <div class="success-icon"><i class="fas fa-check"></i></div>
                        <h3 class="success-title">Письмо отправлено!</h3>
                        <p class="success-text">Проверьте вашу почту</p>
                        <button class="btn" onclick="switchTab('login')"><span class="btn-text">Вернуться ко входу</span></button>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <div class="modal-overlay" id="apiModal">
        <div class="modal-box">
            <h4 class="modal-title">Регистрация</h4>
            <p style="color:var(--text2);margin-bottom:20px">Укажите свой e-mail:</p>
            <div class="input-wrap" style="margin-bottom:15px">
                <input type="email" class="form-input" id="api_email" placeholder="E-mail" style="padding-left:18px">
            </div>
            <div class="result" id="apiResult"></div>
            <button class="btn" id="apiRegBtn">Зарегистрироваться</button>
            <button class="btn modal-close" onclick="hideApiModal()">Отмена</button>
        </div>
    </div>
    
    <!-- CYBER POPUP - Аккаунт не найден -->
    <div class="cyber-popup-overlay" id="noAccountPopup">
        <div class="cyber-popup">
            <div class="cyber-popup-corner-tl"></div>
            <div class="cyber-popup-corner-tr"></div>
            <div class="cyber-popup-corner-bl"></div>
            <div class="cyber-popup-corner-br"></div>
            <button class="cyber-popup-close" onclick="hideCyberPopup()"><i class="fas fa-times"></i></button>
            
            <div class="cyber-popup-header">
                <div class="cyber-popup-icon"><i class="fas fa-user-slash"></i></div>
                <h3 class="cyber-popup-title">Аккаунт не найден</h3>
            </div>
            
            <div class="cyber-popup-body">
                <p class="cyber-popup-text">
                    Ваш аккаунт <strong>Steam</strong> или <strong>VK</strong> не привязан к нашему проекту.<br>
                    Для входа необходимо сначала зарегистрироваться.
                </p>
                
                <div class="cyber-popup-hint">
                    <p><i class="fas fa-lightbulb"></i> Перейдите на вкладку "Регистрация" и выберите Steam или VK</p>
                </div>
                
                <button class="cyber-popup-btn" onclick="hideCyberPopup(); switchTab('register');">
                    <i class="fas fa-user-plus"></i> Перейти к регистрации
                </button>
            </div>
        </div>
    </div>
    
    <div style="display:none" id="conf-mess">{conf_mess}</div>

    <script src="{site_host}templates/{template}/js/jquery.js"></script>
    {if($conf->captcha != '2')}
    <script src="https://www.google.com/recaptcha/api.js?hl=ru" async defer></script>
    {/if}
    
    <script>
    var siteHost = '{site_host}';
    var currentApiType = '';
    
    // Проверяем авторизацию после загрузки jQuery
    $(document).ready(function() {
        var oauthAttempt = sessionStorage.getItem('oauth_login_attempt');
        
        $.ajax({
            type: 'POST',
            url: siteHost + 'ajax/fast_actions.php',
            data: { get_user_data: 1 },
            dataType: 'json',
            success: function(r) {
                if(r && r.id && parseInt(r.id) > 0) {
                    // Авторизован - очищаем флаг и редиректим
                    sessionStorage.removeItem('oauth_login_attempt');
                    window.location.href = siteHost;
                } else {
                    // Не авторизован - проверяем был ли OAuth
                    if(oauthAttempt) {
                        sessionStorage.removeItem('oauth_login_attempt');
                        setTimeout(function() { showCyberPopup(); }, 3000);
                    }
                }
            },
            error: function() {
                // При ошибке тоже проверяем флаг
                if(oauthAttempt) {
                    sessionStorage.removeItem('oauth_login_attempt');
                    setTimeout(function() { showCyberPopup(); }, 3000);
                }
            }
        });
    });
    
    window.addEventListener('load', function() {
        setTimeout(function() {
            document.getElementById('preloader').classList.add('hidden');
            var v = document.getElementById('bgVideo');
            if(v) v.play().catch(function(){});
            createParticles();
        }, 2500);
    });
    
    function switchTab(name) {
        document.querySelectorAll('.tab').forEach(function(t) { t.classList.remove('active'); if(t.dataset.tab === name) t.classList.add('active'); });
        document.querySelectorAll('.tab-content').forEach(function(c) { c.classList.remove('active'); if(c.id === name) c.classList.add('active'); });
        document.querySelectorAll('.result').forEach(function(r) { r.classList.remove('show'); });
        var rs = document.getElementById('resetSuccess'), rf = document.getElementById('resetFormWrap');
        if(rs) rs.classList.remove('show');
        if(rf) rf.style.display = 'block';
    }
    document.querySelectorAll('.tab').forEach(function(t) { t.addEventListener('click', function() { switchTab(t.dataset.tab); }); });
    
    var soundBtn = document.getElementById('soundBtn'), video = document.getElementById('bgVideo'), muted = true;
    soundBtn.addEventListener('click', function() { muted = !muted; video.muted = muted; soundBtn.classList.toggle('muted', muted); soundBtn.innerHTML = muted ? '<i class="fas fa-volume-xmark"></i>' : '<i class="fas fa-volume-high"></i>'; });
    
    function togglePass(id, btn) { var inp = document.getElementById(id), ico = btn.querySelector('i'); if(inp.type === 'password') { inp.type = 'text'; ico.classList.replace('fa-eye', 'fa-eye-slash'); } else { inp.type = 'password'; ico.classList.replace('fa-eye-slash', 'fa-eye'); } }
    
    var regPass = document.getElementById('reg_password');
    if(regPass) { regPass.addEventListener('input', function() { var p = this.value, s = 0; if(p.length >= 6) s++; if(p.length >= 10) s++; if(/[a-z]/.test(p) && /[A-Z]/.test(p)) s++; if(/\d/.test(p)) s++; if(/[^a-zA-Z0-9]/.test(p)) s++; var fill = document.getElementById('strengthFill'), text = document.getElementById('strengthText'); fill.className = 'strength-fill'; text.className = 'strength-text'; if(p.length === 0) { text.textContent = 'Введите пароль'; } else if(s <= 1) { fill.classList.add('weak'); text.classList.add('weak'); text.textContent = 'Слабый'; } else if(s <= 2) { fill.classList.add('fair'); text.classList.add('fair'); text.textContent = 'Средний'; } else if(s <= 3) { fill.classList.add('good'); text.classList.add('good'); text.textContent = 'Хороший'; } else { fill.classList.add('strong'); text.classList.add('strong'); text.textContent = 'Отличный!'; } }); }
    
    function showResult(id, type, msg) { var el = document.getElementById(id); el.className = 'result show ' + type; var icon = type === 'success' ? '<i class="fas fa-check-circle result-icon"></i>' : '<i class="fas fa-exclamation-triangle result-icon"></i>'; el.innerHTML = icon + '<span>' + msg + '</span>'; }
    
    function oAuthLogin(type) { 
        var method = 'get_' + type + '_auth_link', data = {}; 
        data[method] = true; 
        $.ajax({ 
            type: 'POST', 
            url: siteHost + 'ajax/fast_actions.php', 
            data: data, 
            dataType: 'json', 
            success: function(r) { 
                if(r.url && r.url !== '#') { 
                    // Сохраняем флаг что пытаемся войти через OAuth
                    sessionStorage.setItem('oauth_login_attempt', type);
                    location.href = r.url; 
                } else { 
                    showResult('loginResult', 'error', 'OAuth временно недоступен'); 
                } 
            }, 
            error: function() { showResult('loginResult', 'error', 'Ошибка соединения'); } 
        }); 
    }
    window.oAuthLogin = oAuthLogin;
    
    document.getElementById('loginForm').addEventListener('submit', function(e) {
        e.preventDefault();
        var btn = document.getElementById('loginBtn'), login = document.getElementById('login_user').value.trim(), pass = document.getElementById('login_pass').value, token = document.getElementById('token').value;
        if(!login || !pass) { showResult('loginResult', 'error', 'Заполните все поля'); return; }
        btn.classList.add('loading');
        $.ajax({
            type: 'POST', url: siteHost + 'ajax/actions.php',
            data: 'phpaction=1&token=' + token + '&user_login=1&login=' + encodeURIComponent(login) + '&password=' + encodeURIComponent(pass),
            success: function(html) {
                btn.classList.remove('loading');
                if(html.indexOf('reset_page()') !== -1 || html.indexOf('location') !== -1 || html === '') { showResult('loginResult', 'success', 'Добро пожаловать!'); setTimeout(function() { location.href = siteHost; }, 1500); }
                else { var m = html.match(/<p[^>]*class="[^"]*text-danger[^"]*"[^>]*>(.*?)<\/p>/i); showResult('loginResult', 'error', m ? m[1] : 'Неверный логин или пароль'); }
            },
            error: function() { btn.classList.remove('loading'); showResult('loginResult', 'error', 'Ошибка соединения'); }
        });
    });
    
    var regForm = document.getElementById('regForm');
    if(regForm) {
        regForm.addEventListener('submit', function(e) {
            e.preventDefault();
            var btn = document.getElementById('regBtn'), login = document.getElementById('reg_login').value.trim(), email = document.getElementById('reg_email').value.trim(), pass = document.getElementById('reg_password').value, pass2 = document.getElementById('reg_password2').value, token = document.getElementById('token').value, captcha = '';
            if(typeof grecaptcha !== 'undefined') captcha = grecaptcha.getResponse();
            if(!login || !email || !pass || !pass2) { showResult('regResult', 'error', 'Заполните все поля'); return; }
            if(pass !== pass2) { showResult('regResult', 'error', 'Пароли не совпадают'); return; }
            if(pass.length < 6) { showResult('regResult', 'error', 'Пароль минимум 6 символов'); return; }
            btn.classList.add('loading');
            $.ajax({
                type: 'POST', url: siteHost + 'ajax/actions.php',
                data: 'phpaction=1&token=' + token + '&registration=1&login=' + encodeURIComponent(login) + '&password=' + encodeURIComponent(pass) + '&password2=' + encodeURIComponent(pass2) + '&email=' + encodeURIComponent(email) + '&captcha=' + encodeURIComponent(captcha),
                success: function(html) {
                    btn.classList.remove('loading');
                    if(typeof grecaptcha !== 'undefined') grecaptcha.reset();
                    if(html.indexOf('text-success') !== -1) { var m = html.match(/class="[^"]*text-success[^"]*"[^>]*>([^<]+)/i); var msg = (m && m[1] && m[1].trim()) ? m[1].trim() : 'Регистрация успешна! Проверьте почту.'; showResult('regResult', 'success', msg); setTimeout(function() { switchTab('login'); }, 3000); }
                    else { var m = html.match(/<p[^>]*class="[^"]*text-danger[^"]*"[^>]*>(.*?)<\/p>/i); showResult('regResult', 'error', m ? m[1] : 'Ошибка регистрации'); }
                },
                error: function() { btn.classList.remove('loading'); showResult('regResult', 'error', 'Ошибка соединения'); }
            });
        });
    }
    
    document.getElementById('resetForm').addEventListener('submit', function(e) {
        e.preventDefault();
        var btn = document.getElementById('resetBtn'), email = document.getElementById('reset_email').value.trim(), token = document.getElementById('token').value, captcha = '';
        if(typeof grecaptcha !== 'undefined') captcha = grecaptcha.getResponse();
        if(!email) { showResult('resetResult', 'error', 'Введите email'); return; }
        btn.classList.add('loading');
        $.ajax({
            type: 'POST', url: siteHost + 'ajax/actions.php',
            data: 'phpaction=1&token=' + token + '&send_new_pass=1&email=' + encodeURIComponent(email) + '&captcha=' + encodeURIComponent(captcha),
            success: function(html) {
                btn.classList.remove('loading');
                if(typeof grecaptcha !== 'undefined') grecaptcha.reset();
                if(html.indexOf('text-success') !== -1) { document.getElementById('resetFormWrap').style.display = 'none'; document.getElementById('resetSuccess').classList.add('show'); }
                else { var m = html.match(/<p[^>]*class="[^"]*text-danger[^"]*"[^>]*>(.*?)<\/p>/i); showResult('resetResult', 'error', m ? m[1] : 'Ошибка'); }
            },
            error: function() { btn.classList.remove('loading'); showResult('resetResult', 'error', 'Ошибка соединения'); }
        });
    });
    
    function showApiModal(type) { currentApiType = type; document.getElementById('apiModal').classList.add('show'); document.getElementById('api_email').value = ''; document.getElementById('apiResult').classList.remove('show'); }
    function hideApiModal() { document.getElementById('apiModal').classList.remove('show'); }
    
    document.getElementById('apiRegBtn').addEventListener('click', function() {
        var email = document.getElementById('api_email').value.trim();
        if(!email) { showResult('apiResult', 'error', 'Введите email'); return; }
        this.classList.add('loading'); var btn = this;
        $.ajax({
            type: 'POST', url: siteHost + 'ajax/fast_actions.php',
            data: 'reg_by_api=1&email=' + encodeURIComponent(email) + '&type=' + currentApiType, dataType: 'json',
            success: function(r) {
                btn.classList.remove('loading');
                if(r.data) { if(r.data.indexOf('text-success') !== -1 || r.data.indexOf('location.href') !== -1) { var u = r.data.match(/location\.href\s*=\s*["']([^"']+)["']/); if(u) location.href = u[1]; else { showResult('apiResult', 'success', 'Успешно!'); setTimeout(function() { location.reload(); }, 1500); } } else { var m = r.data.match(/<p[^>]*class="[^"]*text-danger[^"]*"[^>]*>(.*?)<\/p>/i); showResult('apiResult', 'error', m ? m[1] : 'Ошибка'); } }
                else if(r.url) location.href = r.url;
                else showResult('apiResult', 'error', r.message || 'Ошибка');
            },
            error: function() { btn.classList.remove('loading'); showResult('apiResult', 'error', 'Ошибка соединения'); }
        });
    });
    
    function createParticles() { 
        if(window.innerWidth <= 540) return; // Не создаём частицы на мобильных
        var c = document.getElementById('particles'); 
        var count = window.innerWidth <= 768 ? 10 : 20; // Оптимизированное количество
        for(var i = 0; i < count; i++) { 
            var p = document.createElement('div'); 
            p.className = 'particle'; 
            p.style.left = Math.random() * 100 + '%'; 
            p.style.animationDelay = Math.random() * 10 + 's'; 
            p.style.animationDuration = (Math.random() * 10 + 20) + 's'; 
            c.appendChild(p); 
        } 
    }
    
    // Cyber Popup функции
    function showCyberPopup() {
        document.getElementById('noAccountPopup').classList.add('show');
    }
    function hideCyberPopup() {
        document.getElementById('noAccountPopup').classList.remove('show');
    }
    
    // Обработка сообщений от GameCMS
    var confMess = document.getElementById('conf-mess');
    if(confMess) {
        var p = confMess.querySelector('p');
        if(p && p.textContent.trim()) {
            var msg = p.textContent.trim().toLowerCase();
            // Проверяем сообщения связанные с отсутствием аккаунта
            if(msg.indexOf('не найден') !== -1 || msg.indexOf('не зарегистрирован') !== -1 || msg.indexOf('not found') !== -1 || msg.indexOf('не существует') !== -1 || msg.indexOf('отсутствует') !== -1) {
                setTimeout(function() { showCyberPopup(); }, 3000);
            } else {
                setTimeout(function() { showResult('loginResult', p.className.indexOf('danger') !== -1 ? 'error' : 'success', p.textContent.trim()); }, 3000);
            }
        }
    }
    
    // Проверка URL параметров (если GameCMS передает ошибку через URL)
    var urlParams = new URLSearchParams(window.location.search);
    if(urlParams.get('error') === 'no_account' || urlParams.get('auth_error') === '1') {
        setTimeout(function() { showCyberPopup(); }, 3000);
    }
    </script>
</body>
</html>
