<!-- Cyber Background Effects -->
<div class="cyber-bg-effects">
	<div class="cyber-grid"></div>
	<div class="cyber-particles" id="cyberParticles"></div>
	<div class="cyber-scanlines"></div>
</div>

<div class="container-fluid wapper">
	<div class="content">
		<!-- CYBER HEADER -->
		<div class="header cyber-header">
			<div class="header-glow"></div>
			<div class="container">
				<div class="header-content">
					<!-- Mobile Menu Trigger -->
					<button class="menu-trigger cyber-menu-trigger d-block d-lg-none" type="button" data-toggle="collapse" data-target="#hidden-menu">
						<span class="trigger-line"></span>
						<span class="trigger-line"></span>
						<span class="trigger-line"></span>
					</button>
					
					<!-- Navigation Menu -->
					<div class="collapse d-none d-lg-block" id="hidden-menu">
						<nav class="cyber-nav">
							<ul class="collapsible-menu cyber-menu">
								{menu}
							</ul>
						</nav>
					</div>
					
					<!-- Auth Button -->
					<button class="auth-in cyber-auth-btn" data-toggle="modal" data-target="#authorization">
						<i class="fas fa-user-astronaut"></i>
						<span>Войти</span>
						<div class="btn-glow"></div>
					</button>
				</div>
			</div>
		</div>
		
		<!-- CYBER BREADCRUMB -->
		<div class="navigation cyber-navigation">
			<div class="container">
				<div class="cyber-breadcrumb-wrap">
					<div class="breadcrumb-icon">
						<i class="fas fa-terminal"></i>
					</div>
					<ul class="breadcrumb cyber-breadcrumb">
						{page_name}
					</ul>
					<div class="breadcrumb-status">
						<span class="status-dot online"></span>
						<span class="status-text">SYSTEM ONLINE</span>
					</div>
				</div>
			</div>
		</div>
	
		<div class="container">
			{include file="parts/page_head.tpl"}

			<!-- CYBER AUTH MODAL -->
			<div id="authorization" class="modal fade cyber-modal">
				<div class="modal-dialog modal-sm">
					<div class="modal-content">
						<div class="modal-header">
							<button type="button" class="close" data-dismiss="modal" aria-label="Close">
								<span aria-hidden="true">&times;</span>
							</button>
							<h4 class="modal-title">Авторизация</h4>
						</div>
						<div class="modal-body">
							<form id="user_login" class="authorization">
								<input type="text" maxlength="30" class="form-control" id="user_loginn" placeholder="Логин">
								<input type="password" maxlength="15" class="form-control" id="user_password" placeholder="Пароль">
								<button type="submit" class="btn btn-primary btn-block">Войти</button>

								<div id="result" class="disp-n"></div>

								<a href="../recovery" class="small">Забыли пароль?</a>
								<a class="small ml-2" onclick="$('#authorization').modal('hide');" href="#" data-toggle="modal" data-target="#registration">Регистрация</a><br>

								{if($auth_api->steam_api == 1)}
									<a class="btn btn-outline-primary" href="#" id="steam_link" title="Войти через Steam"><i class="m-icon icon-steam"></i></a>
								{/if}
								{if($auth_api->vk_api == 1)}
									<a class="btn btn-outline-primary" href="#" id="vk_link" title="Войти через Вконтакте"><i class="m-icon icon-vk"></i></a>
								{/if}
								{if($auth_api->fb_api == 1)}
									<a class="btn btn-outline-primary" href="#" id="fb_link" title="Войти через Facebook"><i class="m-icon icon-fb"></i></a>
								{/if}
							</form>
							<script> send_form('#user_login', 'user_login();'); </script>
						</div>
					</div>
				</div>
			</div>

			<div id="registration" class="modal fade">
				<div class="modal-dialog modal-sm">
					<div class="modal-content">
						<div class="modal-header">
							<button type="button" class="close" data-dismiss="modal" aria-label="Close">
								<span aria-hidden="true">&times;</span>
							</button>
							<h4 class="modal-title">Регистрация</h4>
						</div>
						<div class="modal-body">
							<form id="user_registration" class="registration">
                                {if($conf->standard_registration)}
									<input type="text" maxlength="30" class="form-control" id="reg_login" placeholder="Логин">
									<input type="password" maxlength="15" class="form-control" id="reg_password" placeholder="Пароль">
									<input type="password" maxlength="15" class="form-control" id="reg_password2" placeholder="Повторите пароль">
									<input type="email" maxlength="255" class="form-control" id="reg_email" placeholder="E-mail {if($conf->conf_us == 1)}(Указывайте настоящий e-mail!){/if}">
                                {/if}

								{if($conf->privacy_policy == 1)}
									<a class="privacy-policy" href="../processing-of-personal-data" target="_blank">Регистрируясь на данном сайте, Вы выражаете согласие на обработку персональных данных</a>
								{/if}

                                {if($conf->standard_registration)}
									{if($conf->captcha != '2')}
										<div style="transform:scale(0.75);-webkit-transform:scale(0.75);transform-origin:0 0;-webkit-transform-origin:0 0;" data-theme="light" class="g-recaptcha clearfix" data-sitekey="{{$conf->captcha_client_key}}"></div>
										<script src='https://www.google.com/recaptcha/api.js?hl=ru'></script>
									{/if}

									<div id="result2"></div>

									<button type="submit" class="btn btn-primary btn-block mt-2">Зарегистрироваться</button>
                                {/if}

								{if($auth_api->vk_api == 1)}
									<a class="btn btn-outline-primary" onclick="$('#registration').modal('hide'); show_reg_modal('vk');" title="Зарегистрироваться через Вконтакте"><i class="m-icon icon-vk"></i></a>
								{/if}
								{if($auth_api->steam_api == 1)}
									<a class="btn btn-outline-primary" onclick="$('#registration').modal('hide'); show_reg_modal('steam');" title="Зарегистрироваться через Steam"><i class="m-icon icon-steam"></i></a>
								{/if}
								{if($auth_api->fb_api == 1)}
									<a class="btn btn-outline-primary" onclick="$('#registration').modal('hide'); show_reg_modal('fb');" title="Зарегистрироваться через Facebook"><i class="m-icon icon-fb"></i></a>
								{/if}
							</form>
							<script> send_form('#user_registration', 'registration();'); </script>
						</div>
					</div>
				</div>
			</div>

			<div id="api_auth" class="modal fade">
				<div class="modal-dialog">
					<div class="modal-content">
						<div class="modal-header">
							<button type="button" class="close" data-dismiss="modal" aria-label="Close">
								<span aria-hidden="true">&times;</span>
							</button>
							<h4 class="modal-title">Регистрация</h4>
						</div>
						<div class="modal-body">
							<p>Укажите, пожалуйста, свой e-mail.</p>

							<input type="email" maxlength="255" class="form-control" id="api_email" placeholder="E-mail {if($conf->conf_us == 1)}(Требуется настоящий e-mail!){/if}">
							
							<div id="result_api_reg"></div>
							<button id="api_reg_btn" class="btn btn-primary btn-block mt-2" onclick="">Зарегистрироваться</button>
						</div>
					</div>
				</div>
			</div>

			<div class="row">