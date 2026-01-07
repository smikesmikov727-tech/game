<div class="block">
	<div class="block_head">
		Навигация
	</div>
	<div class="vertical-navigation">
		<ul>
            {if(!empty($vertical_menu))}
				{for($i=0;$i < count($vertical_menu);$i++)}
				<li>
					<a href="{{$vertical_menu[$i]['link']}}">{{$vertical_menu[$i]['name']}}</a>
				</li>
				{/for}
			{/if}
		</ul>
	</div>
</div>