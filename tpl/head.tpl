	<head>
		<meta charset="utf-8">
		<title>{title}</title>

		<!-- Google Fonts for Cyber/Modern Theme -->
		{if($theme == 3 || $theme == 4)}
		<link rel="preconnect" href="https://fonts.googleapis.com">
		<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
		<link href="https://fonts.googleapis.com/css2?family=Orbitron:wght@400;500;600;700;800;900&family=Rajdhani:wght@300;400;500;600;700&family=Share+Tech+Mono&display=swap" rel="stylesheet">
		<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
		{/if}

		<link rel="stylesheet" href="{site_host}templates/{template}/css/main.css?v={cache}">
        {if($theme == 1)}
			<link rel="stylesheet" href="{site_host}templates/{template}/css/theme_dark.css?v={cache}">
        {/if}
        {if($theme == 2)}
			<link rel="stylesheet" href="{site_host}templates/{template}/css/theme_ghost.css?v={cache}">
        {/if}
        {if($theme == 3)}
			<link rel="stylesheet" href="{site_host}templates/{template}/css/theme_cyber.css?v={cache}">
        {/if}
        {if($theme == 4)}
			<link rel="stylesheet" href="{site_host}templates/{template}/css/theme_modern.css?v={cache}">
        {/if}

		<link rel="shortcut icon" href="{site_host}templates/{template}/img/favicon.ico?v={cache}">
		<link rel="image_src" href="{image}?v={cache}">

		<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
		<meta name="robots" content="{robots}">
		<meta name="revisit" content="1">
		<meta name="description" content="{description}">
		<meta name="keywords" content="{keywords}">
		<meta name="document-state" content="dynamic">
		<meta name="author" content="gamecms.ru">

		<meta property="og:title" content="{title}">
		<meta property="og:description" content="{description}">
		<meta property="og:type" content="{type}">
		<meta property="og:image" content="{image}?v={cache}">
		<meta property="og:site_name" content="{site_name}">
		<meta property="og:url" content="{url}">

		<meta name="dc.title" content="{title}">
		<meta name="dc.rights" content="Copyright 2015, gr.stas, Ltd. Все права защищены.">
		<meta name="dc.creator" content="gamecms.ru">
		<meta name="dc.language" content="RU">

		<script src="{site_host}templates/{template}/js/jquery.js?v={cache}"></script>
		<script src="{site_host}templates/{template}/js/nprogress.js?v={cache}"></script>
		<script src="{site_host}templates/{template}/js/noty.js?v={cache}"></script>
		<script src="{site_host}templates/{template}/js/mix.js?v={cache}"></script>
		<script src="{site_host}templates/{template}/js/bootstrap.js?v={cache}"></script>

		<script src="{site_host}ajax/helpers.js?v={cache}"></script>
		<script src="{site_host}ajax/ajax-user.js?v={cache}"></script>

		{if($conf->new_year == 1 || $conf->win_day == 1)}
		<link rel="stylesheet" href="{site_host}templates/{template}/css/holiday.css?v={cache}">
		<script src="{site_host}templates/{template}/js/holiday.js?v={cache}"></script>
		{/if}

		{files}
		{other}
	</head>
	<body>
		{if($conf->new_year == 1)}
			{include file="/elements/new_year.tpl"}
		{/if}
		{if($conf->win_day == 1)}
			{include file="/elements/win_day.tpl"}
		{/if}

		<input id="token" type="hidden" value="{token}">

		<div id="global_result">
			<span class="m-icon icon-ok result_ok disp-n"></span>
			<span class="m-icon icon-remove result_error disp-n"></span>
			<span class="m-icon icon-ok result_ok_b disp-n"></span>
			<span class="m-icon icon-remove result_error_b disp-n"></span>
		</div>
		<div id="result_player"></div>