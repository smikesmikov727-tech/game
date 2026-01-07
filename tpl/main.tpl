{include file="config.tpl"}
{if($show_auth_page == 1 && !is_auth())}
	{include file="auth/login.tpl"}
{else}
<!DOCTYPE html>
<html lang="ru">
	{if($conf->off == 1 && !is_admin())}
		{include file="off_site.tpl"}
	{else}
		{content}
	{/if}
</html>
{/if}