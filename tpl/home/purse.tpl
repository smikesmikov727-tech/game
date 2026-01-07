<div class="col-lg-9 order-is-first">

    {if('{success}' == '1')}
		<div class="noty-block success">
			<h4>Ваш баланс успешно пополнен!</h4>
			<p><b>{login}</b>, Ваш баланс успешно пополнен!</p>
		</div>
    {/if}
    {if('{fail}' == '1')}
		<div class="noty-block error">
			<h4>Внимание! Ваш баланс не пополнен!</h4>
			<p>Возможно произошла ошибка, либо Вы отменили платеж.</p>
		</div>
    {/if}

	<div class="block purse">
		<div class="row">
			<div class="col-lg-3">
				<div>
					<i class="fas fa-ruble-sign"></i>
					Баланс<br>
					<font id="my_balance">{balance}</font>{{$messages['RUB']}}
				</div>
			</div>
			<div class="col-lg-3">
				<div data-target="#voucher" data-toggle="modal">
					<i class="fas fa-barcode"></i>
					Активировать<br>
					ваучер
				</div>
			</div>
			<div class="col-lg-3">
				<div>
					<i class="fas fa-star"></i>
					Скидка<br>
                    {proc}%
				</div>
			</div>
			<div class="col-lg-3 d-none d-lg-block" onclick="scrollToBox('#last_operations');">
				<div>
					<i class="fas fa-shopping-cart"></i>
					Последние<br>
					операции
				</div>
			</div>
		</div>
	</div>

	{if('{bonusesActivity}' == '1')}
		<div class="block">
			<div class="block_head">
				Бонусы
			</div>

			<div class="row">
				{for($i = 0; $i < count($bonuses); $i++)}
					<div class="col-lg-{if(count($bonuses) % 4 == 0)}3{else}{if(count($bonuses) % 3 == 0)}4{else}{if(count($bonuses) % 2 == 0)}6{else}12{/if}{/if}{/if}">
						<div class="noty-block">
							<h5>+{{$bonuses[$i]['value']}}{if($bonuses[$i]['type'] == 1)}{{$messages['RUB']}}{else}%{/if}</h5>
							При пополнении на сумму от {{$bonuses[$i]['start']}} до {{$bonuses[$i]['end']}}{{$messages['RUB']}}
						</div>
					</div>
				{/for}
			</div>
		</div>
	{/if}

	<div class="row pay_area">
		{foreach($merchants as $slug => $merchant)}
			{if($merchantsSettings->$slug == 1)}
				<div class="col-md-6">
					<div class="block">
						<div class="block_head">
							{{$merchant['title']}}
						</div>
						<label for="number_{{$slug}}">
							<img src="../files/merchants/{{$merchant['image']}}" alt="{{$merchant['title']}}">
						</label>
						<input class="form-control" id="number_{{$slug}}" placeholder="Укажите сумму" value="{price}">
						<div id="balance_result_{{$slug}}" class="mt-3"></div>
						<button class="btn btn-outline-primary btn-xl" onclick="refill_balance('{{$slug}}');">Пополнить баланс</button>
					</div>
				</div>
			{/if}
		{/foreach}
	</div>

	<script>$('#voucher').modal('hide');</script>
	<div id="voucher" class="modal fade">
		<div class="modal-dialog">
			<div class="modal-content">
				<div class="modal-header">
					<button type="button" class="close" data-dismiss="modal" aria-label="Close">
						<span aria-hidden="true">&times;</span>
					</button>
					<h4 class="modal-title">Активация ваучера</h4>
				</div>
				<div class="modal-body">
					<input class="form-control" type="text" id="voucher_key" placeholder="Введите ваучер" maxlength="50">
					<button class="btn btn-primary" onclick="activate_voucher();">Активировать</button>
					<br>
					<div id="activate_result"></div>
				</div>
			</div>
		</div>
	</div>

	<div class="block block-table" id="last_operations">
		<div class="block_head">
			Последние операции
		</div>
		<div class="table-responsive mb-0">
			<table class="table table-bordered">
				<thead>
				<tr>
					<td>Сумма</td>
					<td>Тип</td>
					<td>Дата</td>
				</tr>
				</thead>
				<tbody id="operations">
				<tr>
					<td colspan="10">
						<div class="loader"></div>
						<script>get_operations();</script>
					</td>
				</tr>
				</tbody>
			</table>
		</div>
	</div>
</div>

<div class="col-lg-3 order-is-last">
    {include file="/home/navigation.tpl"}
    {include file="/home/sidebar.tpl"}
</div>