package controller::clientes;

use strict;
use base 'controller::usuarios::management';
use Sort::Key qw/nkeysort keysort/;

sub new {

	my ( $n, $d ) = @_;

	my $x = {
		v => view::render->new( $d->{r} ),
		m => model::init->new( $d->{dbh} ),
	};

	bless $x;
	return $x;

}

sub default {

	my ( $x, $d ) = @_;

	my %options = (
		include_membership   => 1,
		include_debt_details => 1,
	);

	if ( $d->{p}->{felicidades} eq 'hoy' ) {
		$options{todays_birthdays} = 1;
		$d->{data}->{hide_filters} = 1;
	}
	elsif ( $d->{p}->{felicidades} eq 'prox' ) {
		$options{upcoming_birthdays} = 1;
		$d->{data}->{hide_filters} = 1;
	}

	my $is_responsible_for_group_membership = 0;
	my $is_dependent                        = 0;

	my $ctip    = controller::tips->new($d);
	my $clients = $x->{m}->{clients}->get_clients(%options);

	if ($clients) {

		my $show_inactive_debt_message = 0;
		my @active;
		my @inactive;

		my %memberships_tmp;
		my %totals;

		foreach my $cc ( @{$clients} ) {

			if ( $cc->{active} && ( $cc->{is_admin} || $cc->{is_coach} ) ) {
				$memberships_tmp{STAFF} = { name => 'Staff', income => 0 };
				$totals{staff}++;
				push @active, $cc;
			}
			else {

				if ( $cc->{active} ) {

					$memberships_tmp{ $cc->{membership}->{membership_id} } = {
						name   => $cc->{membership}->{name},
						income => 0,
					};

					$totals{clients}++;

					if ( $cc->{debt}->{membership}->{expired} ) {
						$totals{expired}++;
					}
					else {
						$totals{membership_ok}++;
					}

					push @active, $cc;

				}
				else {
					$memberships_tmp{INACTIVE} = { name => 'Deshabilitados', income => 0 };
					$totals{inactive}++;
					push @inactive, $cc;
				}

			}

			if ( $cc->{debt}->{total} > 0 ) {

				$totals{have_debt}++;

				# force it into the clients screen if inactive but has outstanding debt
				if ( !$cc->{active} ) {
					push @active, $cc;
					$totals{inactive_with_debt}++;
					$show_inactive_debt_message = 1;
				}

			}

		}

		$memberships_tmp{STAFF}->{users} = $totals{staff};
		$memberships_tmp{INACTIVE}->{users} = $totals{inactive_with_debt};

		if ( $totals{clients} > 0 ) {

			my $usage = $x->{m}->{memberships}->get_usage();

			if ($usage) {

				my @client_distribution;
				my @income_distribution;
				$d->{data}->{total_membership_income} = 0;

				foreach my $mm ( values %{$usage} ) {
					$memberships_tmp{ $mm->{id} }->{income} = $mm->{income};
					$memberships_tmp{ $mm->{id} }->{users}  = $mm->{total};
					push @client_distribution, { $mm->{name} => $mm->{total} };
					push @income_distribution, { $mm->{name} => $mm->{income} } if $mm->{income} > 0;
					$d->{data}->{total_membership_income} += $mm->{income};
				}

				$d->{data}->{charts}->{clients} = global::charts->pie(
					title  => 'Clientes',
					color  => 'blue',
					values => \@client_distribution,
					div_id => 'DIV-MEMBERSHIPS-CLIENT-CHART',
					others => 7,
				);

				$d->{data}->{charts}->{income} = global::charts->pie(
					monify => 1,
					others => 7,
					title  => 'Ingresos',
					color  => 'green',
					values => \@income_distribution,
					div_id => 'DIV-MEMBERSHIPS-INCOME-CHART',
				) if scalar @income_distribution;

			}

		}

		my @memberships;
		foreach my $membership_id ( keys %memberships_tmp ) {
			push @memberships,
			  {
				id     => $membership_id,
				name   => $memberships_tmp{$membership_id}->{name},
				income => $memberships_tmp{$membership_id}->{income},
				users  => $memberships_tmp{$membership_id}->{users},
			  };
		}

		my @sorted_memberships = keysort { $_->{name} } @memberships;
		my @sorted_clients = nkeysort { $_->{debt}->{membership}->{days} } @active;

		$d->{data}->{memberships} = \@sorted_memberships;
		$d->{data}->{totals}      = \%totals;
		$d->{data}->{clients}     = \@sorted_clients;
		$d->{data}->{inactive}    = \@inactive;

		if ($show_inactive_debt_message) {
			my $tip = $ctip->get(
				tip     => 'INACTIVE-DEBT-USERS',
				user_id => $d->{s}->{user_id}
			);
			$d->info($tip) if $tip;
		}

	}
	else {
		$d->info('No se han encontrado clientes.');
	}

	$d->{data}->{deleted_user_count} = $x->{m}->count( table => '_g_deleted_users' );

	my $tip = $ctip->get(
		tip     => 'USERS-PUBLICO-GENERAL',
		user_id => $d->{s}->{user_id}
	);
	$d->info($tip) if $tip;

	$x->{v}->render($d);

}

sub agregar {

	my ( $x, $d ) = @_;

	$d->{data}->{memberships} = $x->{m}->{memberships}->get_memberships(
		where => {
			'_f_memberships.active' => 1
		}
	);

	unless ( $d->{data}->{memberships} ) {

		my $membership_management_uri = global::ttf->uri( c => 'membresias', method => 'default' );

		$d->info(
			qq{
			No se han agregado membres&iacute;as.
			<br>
			Es necesario agregar membres&iacute;as antes de agregar clientes.
			<br>
			<br>
			<div class=btn-list>
			<a href=$membership_management_uri class="btn btn-secondary">
				<i class="fe fe-repeat mr-2"></i>
				Tipos de de membres&iacute;a
			</a>
			</div>
			}
		  )

	}

	$d->{data}->{details} = $x->{m}->{configuration}->get_additional_details(
		where => {
			'_g_additional_details.active'      => 1,
			'_g_additional_details.for_clients' => 1,
		}
	);

	my $validations = $x->{m}->{configuration}->generate_detail_validations( $d->{data}->{details} )
	  if $d->{data}->{details};

	$d->{data}->{today} = global::date_time->get_date_time_parts()->{day};

	# add a default username and password value so the form validations dont complain
	# in case we dont want to allow_client_access
	$d->{data}->{user} = {
		username => 'DISABLED-' . global::standard->uuid(),
		password => global::standard->uuid(),
	};

	$d->{data}->{user}->{_password} = $d->{data}->{user}->{password};

	$d->{data}->{enrollments} = $x->{m}->{inventory}->get_products(
		where => {
			'_i_items.type_code' => 'ENROLLMENTS',
			'_i_items.active'    => 1
		}
	);

	unless ( $d->{data}->{enrollments} ) {

		my $product_management_uri = global::ttf->uri( c => 'ventas', method => 'default' );

		my $message = qq {
		No se han agregado cobros de inscripci&oacute;n.
		<br>
		<br>
		<div class=btn-list>
		<a href=$product_management_uri class="btn btn-secondary">
			<i class="fe fe-shopping-cart mr-2"></i>
			Productos y servicios
		</a>
		</div>
		};

		$d->info($message);

	}

	$d->{data}->{charge_months} = global::date_time->get_prev_next();
	$d->{data}->{charge_months}->{current} = global::date_time->get_date_time_parts();

	$d->get_form_validations(
		append     => $validations,
		skip_ifdef => [ 'password', '_password' ],
	);

	$x->{v}->render($d);

}

sub upsert_do {

	my ( $x, $d ) = @_;

	my $cff = controller::finanzas->new($d);
	my $cmb = controller::membresias->new($d);

	my $client;

	if ( $d->{p}->{reactivate} ) {

		$x->{m}->update(
			update => { active => 1 },
			where  => { id     => $d->{p}->{id} },
			table  => '_g_users',
		);

		$client = $x->{m}->{users}->get_users(
			where => { '_g_users.id' => $d->{p}->{id} },
			limit => 1,
		);

	}
	else {
		$client = $x->_upsert_user( $d, is_client_upsert => 1 );
	}

	if ( $client->{is_new} || $d->{p}->{reactivate} ) {

		# dependents have the same renewal day as the person responsible for payment
		if ( length $d->{p}->{membership_group_id} && !$d->{p}->{is_responsible_for_group_membership} ) {

			my $membership_group = $x->{m}->{memberships}->get_groups(
				where => { '_f_membership_groups.id' => $d->{p}->{membership_group_id} },
				limit => 1,
			);

			my $responsible_client_membership = $x->{m}->{memberships}->get_client_memberships(
				where => {
					'_f_client_memberships.client_id' => $membership_group->{responsible_client_id},
				},
				limit => 1,
			);

			$d->{p}->{renewal_day} = $responsible_client_membership->{renewal_day};

		}

		$x->{m}->upsert(
			insert => {
				client_id     => $client->{id},
				membership_id => $d->{p}->{membership_id},
				renewal_day   => $d->{p}->{renewal_day}
			},
			conflict_fields => ['client_id'],
			table           => '_f_client_memberships',
		) if $client->{is_new};

	}

	my $membership = $x->{m}->{memberships}->get_client_memberships(
		where => {
			'_f_client_memberships.client_id' => $client->{id},
		},
		limit => 1,
	);

	if ( !$client->{is_new} || $d->{p}->{reactivate} ) {

		# detect if membership ( payment plan ) has changed somehow
		my $membership_has_changed       = 1 if $membership->{membership_id} ne $d->{p}->{membership_id};
		my $renewal_day_has_changed      = 1 if $membership->{renewal_day} ne $d->{p}->{renewal_day};
		my $dependency_group_has_changed = 1 if $membership->{membership_group_id} ne $d->{p}->{membership_group_id};

		my $no_longer_responsible_for_group = 1
		  if $membership->{is_responsible_for_group_membership}
		  && !$d->{p}->{is_responsible_for_group_membership};

		# validate membership change
		if (   ( $membership_has_changed || $no_longer_responsible_for_group )
			&& $membership->{is_responsible_for_group_membership}
			&& $membership->{dependents} )
		{

			my $message = qq{
			<b>No es posible cambiar la membres&iacute;a
			del cliente ya que tiene los siguientes dependientes :</b>
			<br><br>
			};

			foreach my $dep ( @{ $membership->{dependents} } ) {
				$message .= '<i class="fe fe-user"></i> ' . $dep->{display_name} . '<br>';
			}

			my $uri = global::ttf->uri(
				c      => 'membresias',
				method => 'grupo',
				id     => $membership->{membership_group_id}
			);

			$message .= qq{
			<br><br>
			<a href="$uri" class="btn btn-secondary btn-sm">
			<i class="fe fe-users mr-2"></i>
			Administrar membres&iacute;a del grupo
			</a>
			};

			$d->warning($message);
			return $x->{v}->status($d);

		}

		if ( $membership_has_changed || $renewal_day_has_changed ) {

			$x->{m}->update(
				update => {
					membership_id => $d->{p}->{membership_id},
					renewal_day   => $d->{p}->{renewal_day},
				},
				where => { client_id => $client->{id} },
				table => '_f_client_memberships',
			);

			# get a new membership object since if we know its different somehow
			$membership = $x->{m}->{memberships}->get_client_memberships(
				where => {
					'_f_client_memberships.client_id' => $client->{id},
				},
				limit => 1,
			);

			# all group members have the same renewal day
			if ( $membership->{type_code} eq 'G' && $renewal_day_has_changed ) {

				my $membership_group_id = $membership->{membership_group_id} || $d->{p}->{membership_group_id};
				my $group = $x->{m}->{memberships}->get_groups(
					where => { '_f_membership_groups.id' => $membership_group_id },
					limit => 1,
				);

				my %client_ids = ( $group->{responsible_client_id} => 1 );

				if ( $group->{dependents} ) {
					foreach my $dep ( @{ $group->{dependents} } ) {
						$client_ids{ $dep->{id} } = 1;
					}
				}

				$x->{m}->update(
					update => {
						renewal_day => $d->{p}->{renewal_day},
					},
					in => {
						table => '_f_client_memberships',
						field => 'client_id',
						items => [ keys %client_ids ]
					},
					table => '_f_client_memberships',
				);

			}

			if ($membership_has_changed) {

				my @update_membership_charge_ids = map { /^PCH_(\S+)$/ } keys %{ $d->{p} };

				if ( scalar @update_membership_charge_ids ) {

					$x->{m}->update(
						table  => '_f_charges',
						update => {
							membership_id => $membership->{membership_id},
							amount        => $membership->{amount},
						},
						in => {
							table => '_f_charges',
							field => 'id',
							items => \@update_membership_charge_ids,
						}
					);
				}

			}

		}

	}

	if ( $membership->{type_code} eq 'G' ) {
		$cmb->_setup_membership_group(
			$d,
			client_id                           => $client->{id},
			membership_id                       => $membership->{membership_id},
			is_responsible_for_group_membership => $d->{p}->{is_responsible_for_group_membership},
			membership_group_id                 => $d->{p}->{membership_group_id},
		);
	}
	else {
		# if this client was a dependent of a group and now has their own membership
		# we need to remove them from the other group
		$x->{m}->delete(
			where => {
				dependent_client_id => $client->{id}
			},
			table => '_f_membership_group_dependents'
		);

	}

	# if this is a new client and we want to charge the current or prev month, ( not NEXT )
	if ( ( $client->{is_new} || $d->{p}->{reactivate} ) && $d->{p}->{first_charge_month} ne 'NEXT' ) {

		my $parts;
		my $charge_now = 0;

		if ( $d->{p}->{first_charge_month} eq 'CURRENT' ) {
			$parts = global::date_time->get_date_time_parts();
		}
		elsif ( $d->{p}->{first_charge_month} eq 'PREV' ) {
			$parts      = global::date_time->get_prev_next()->{prev};
			$charge_now = 1;
		}

		$cff->charge_client_membership(
			client_id  => $client->{id},
			charge_now => $charge_now,
			month      => $parts->{month},
			year       => $parts->{year},
		);

	}

	if ( $membership->{type_code} eq 'G' && !$membership->{is_responsible_for_group_membership} ) {

		# this is a group dependent, we need to make sure he has all the same charges as his responsible
		$cff->charge_dependent_same_owner_memberships( client_id => $client->{id} );
	}

	if ( $d->{p}->{enrollment_item_id} ) {
		$cff->charge_sale_item(
			$d,
			admin_id  => $d->{s}->{user_id},
			client_id => $client->{id},
			item_id   => $d->{p}->{enrollment_item_id}
		);
	}

	my $message = 'Cliente actualizado.';
	my $method  = 'actualizar';

	if ( $client->{is_new} ) {
		$message = 'Cliente agregado.';
		$method  = 'agregar';
	}
	elsif ( $d->{p}->{reactivate} ) {
		$message = 'Cliente reactivado.';
	}

	$d->success($message);
	$d->save_state();

	return $x->{v}->http_redirect(
		controller => 'clientes',
		method     => $method,
		id         => $client->{is_new} ? undef : $client->{id},
	);

}

sub actualizar {

	my ( $x, $d ) = @_;

	$d->{data}->{user} = $x->{m}->{users}->get_users(
		where => {
			'_g_users.id'        => $d->{p}->{id},
			'_g_users.is_admin'  => 0,
			'_g_users.is_coach'  => 0,
			'_g_users.is_client' => 1,
		},
		limit => 1,
	);

	if ( !$d->{data}->{user}->{active} ) {
		my $ctip = controller::tips->new($d);
		$d->notification(
			$ctip->get(
				tip               => 'DISABLED-USER',
				user_id           => $d->{p}->{id},
				is_client         => $d->{data}->{user}->{is_client},
				no_dismiss_button => 1,
			)
		);
	}

	if ( $d->{data}->{user}->{is_permanent} ) {
		my $ctip = controller::tips->new($d);
		my $tip  = $ctip->get(
			tip               => 'USERS-PUBLICO-GENERAL',
			always_show       => 1,
			no_dismiss_button => 1,
		);
		$tip .= '<br>Este usuario no puede ser modificado o deshabilitado.';
		$d->info($tip) if $tip;
	}

	$d->{data}->{details} = $x->{m}->{configuration}->get_additional_details(
		where => {
			'_g_additional_details.active'      => 1,
			'_g_additional_details.for_clients' => 1,
		}
	);

	$d->{data}->{memberships} = $x->{m}->{memberships}->get_memberships();

	$d->{data}->{membership} = $x->{m}->{memberships}->get_client_memberships(
		where => {
			'_f_client_memberships.client_id' => $d->{p}->{id},
		},
		limit => 1,
	);

	$d->{data}->{group} = $x->{m}->{memberships}->get_groups(
		where => { '_f_membership_groups.id' => $d->{data}->{membership}->{membership_group_id} },
		limit => 1
	) if $d->{data}->{membership}->{is_responsible_for_group_membership};

	if ( $d->{data}->{membership}->{type_code} eq 'G'
		&& !$d->{data}->{membership}->{is_responsible_for_group_membership} )
	{

		my $cmb    = controller::membresias->new($d);
		my $groups = $cmb->get_membership_possible_groups(
			membership_id                => $d->{data}->{membership}->{membership_id},
			selected_group_membership_id => $d->{data}->{membership}->{membership_group_id},
			exclude_client_id            => $d->{p}->{id},
		);

		$d->{data}->{JSON_possible_membership_groups} = JSON::XS->new()->latin1()->encode($groups) if $groups;

	}

	my $validations = $x->{m}->{configuration}->generate_detail_validations( $d->{data}->{details} )
	  if $d->{data}->{details};

	my $cven = controller::ventas->new($d);

	my $statement = $x->{m}->{finance}->get_statement(
		client_id               => $d->{p}->{id},
		only_membership_charges => 1
	);

	$d->{data}->{pending_membership_charges} = $cven->_get_pending_charges_from_statement(
		statement   => $statement,
		no_payments => 1,
	) if $statement;

	$d->get_form_validations( append => $validations );

	$x->{v}->render($d);

}

sub perfil {

	my ( $x, $d ) = @_;

	$d->{data}->{user} = $x->{m}->{users}->get_users(
		where => {
			'_g_users.id' => $d->{p}->{id},
		},
		or => {
			'_g_users.is_client' => 1,
		},
		limit => 1,
	);

	if ( !$d->{data}->{user}->{active} ) {
		my $ctip = controller::tips->new($d);
		$d->notification(
			$ctip->get(
				tip               => 'DISABLED-USER',
				user_id           => $d->{p}->{id},
				is_client         => $d->{data}->{user}->{is_client},
				no_dismiss_button => 1,
			)
		);
	}

	$d->{data}->{membership} = $x->{m}->{memberships}->get_client_memberships(
		where => {
			'_f_client_memberships.client_id' => $d->{p}->{id},
		},
		limit => 1,
	);

	$d->{data}->{calendar} = $x->{m}->{users}->get_calendar(
		user_id     => $d->{p}->{id},
		month       => $d->{p}->{month},
		year        => $d->{p}->{year},
		renewal_day => $d->{data}->{membership}->{renewal_day},
	);

	$d->{data}->{prev_next} = global::date_time->get_prev_next(
		month => $d->{p}->{month},
		year  => $d->{p}->{year}
	);

	$x->{v}->render($d);

}

1;
