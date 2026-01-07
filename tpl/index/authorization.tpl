<div class="block auth-block">
	<div class="block_head">
		<i class="fas fa-user-astronaut"></i> Авторизация
	</div>

	<div style="padding: 20px;">
		<div class="auth-welcome" style="text-align: center; margin-bottom: 20px;">
			<div style="width: 60px; height: 60px; margin: 0 auto 15px; background: linear-gradient(135deg, var(--primary-cyan, #00f0ff), var(--primary-magenta, #ff00aa)); border-radius: 50%; display: flex; align-items: center; justify-content: center;">
				<i class="fas fa-gamepad" style="font-size: 24px; color: #0a0a0f;"></i>
			</div>
			<p style="color: var(--text-secondary, #a0a0b0); font-size: 13px; margin: 0;">Войдите, чтобы получить полный доступ</p>
		</div>

		<a href="../auth" class="btn btn-primary btn-block" style="margin-bottom: 10px;">
			<i class="fas fa-right-to-bracket"></i> Войти на сайт
		</a>
		
		<button class="btn btn-outline-primary btn-block" data-toggle="modal" data-target="#authorization" style="margin-bottom: 10px;">
			<i class="fas fa-sign-in-alt"></i> Быстрый вход
		</button>

		<div style="display: flex; gap: 10px; margin-bottom: 10px;">
			{if($auth_api->vk_api == 1)}
			<a class="btn btn-outline-primary" onclick="oAuthRedirect('get_vk_auth_link')" href="#" id="vk_link" title="Войти через VK" style="flex: 1; padding: 12px;">
				<i class="fab fa-vk"></i>
			</a>
			{/if}
			{if($auth_api->steam_api == 1)}
			<a class="btn btn-outline-primary" onclick="oAuthRedirect('get_steam_auth_link')" href="#" id="steam_link" title="Войти через Steam" style="flex: 1; padding: 12px;">
				<i class="fab fa-steam"></i>
			</a>
			{/if}
		</div>

		<button class="btn btn-secondary btn-block" data-toggle="modal" data-target="#registration">
			<i class="fas fa-user-plus"></i> Регистрация
		</button>
	</div>
</div>