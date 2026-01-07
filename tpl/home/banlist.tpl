<div class="col-lg-9 order-is-first">
	<div class="block block-search">
		<div class="block_head">
			Банлист
		</div>
		{if('{error}' == '')}
		<div class="input-search">
			<i class="fas fa-search" onclick="search_ban({server})"></i>
			<input type="text" class="form-control" id="search_ban" placeholder="Введите nick / steam_id / ip">
			<script> set_enter('#search_ban', 'search_ban({server})'); </script>
		</div>

		<div class="table-responsive mb-0">
			<table class="table table-bordered">
				<thead>
					<tr>
						<td>Ник</td>
						<td>Причина</td>
						<td>Срок</td>
						<td>Дата окончания</td>
						<td>Админ</td>
					</tr>
				</thead>
				<tbody id="banlist">
					{func GetData:banlist("{start}","{server}","{limit}")}
				</tbody>
			</table>
		</div>
		{else}
		<div class="empty-element">
			{error}
		</div>
		{/if}
	</div>

	<div id="pagination2">{pagination}</div>
</div>
<div class="col-lg-3 order-is-last">
	<div class="block">
		<div class="block_head">
			Сервера
		</div>
		<div class="vertical-navigation">
			<ul>
				{servers}
			</ul>
		</div>
	</div>

	<div class="block block-table">
		<div class="block_head">
			Статистика
		</div>
		<div class="table-responsive mb-0">
			<table class="table table-bordered">
				<tr>
					<td width="50%">Всего банов</td>
					<td width="50%">{count}</td>
				</tr>
				<tr>
					<td width="50%">Активные</td>
					<td width="50%">{count_active}</td>
				</tr>
				<tr>
					<td width="50%">Перманентные</td>
					<td width="50%">{count_permanent}</td>
				</tr>
				<tr>
					<td width="50%">Временные</td>
					<td width="50%">{count_temporal}</td>
				</tr>
			</table>
		</div>
	</div>

	{if(is_auth())}
		{include file="/home/navigation.tpl"}
		{include file="/home/sidebar_secondary.tpl"}
	{else}
		{include file="/index/authorization.tpl"}
		{include file="/index/sidebar_secondary.tpl"}
	{/if}
</div>