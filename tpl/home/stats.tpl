<div class="col-lg-9 order-is-first">
	<div class="block block-search">
		<div class="block_head">Статистика</div>
		{if('{error}' == '')}
		<div class="input-search">
			<i class="fas fa-search" onclick="search_stats({server})"></i>
			<input type="text" class="form-control" id="search_stats" placeholder="Введите nick / steam_id / ip">
			<script> set_enter('#search_stats', 'search_stats({server})'); </script>
		</div>

		<div class="table-responsive mb-0">
			<table class="table table-bordered">
				<thead>
					<tr>
						<td>Место</td>
						<td>Ник</td>
						<td>Убийств</td>
						<td>Смертей</td>
						<td>В голову</td>
                        {if(in_array({type}, array(2,7)) && '{isHasRank}')}
							<td>Звание</td>
                        {/if}
                        {if(in_array({type}, array(1,2,3,4,5,7)))}
							<td>Skill</td>
                        {/if}
						{if({type} == 6)}
							<td>Ранг</td>
						{/if}
					</tr>
				</thead>
				<tbody id="stats">
					{func GetData:stats("{start}","{server}","{limit}")}
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

	{if(is_auth())}
		{include file="/home/navigation.tpl"}
		{include file="/home/sidebar_secondary.tpl"}
	{else}
		{include file="/index/authorization.tpl"}
		{include file="/index/sidebar_secondary.tpl"}
	{/if}
</div>