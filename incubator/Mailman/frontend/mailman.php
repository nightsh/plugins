<?php
/**
 * i-MSCP - internet Multi Server Control Panel
 * Copyright (C) 2010-2013 by Laurent Declercq
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * @category    iMSCP
 * @package     iMSCP_Plugin
 * @subpackage  HelloWorld
 * @copyright   Copyright (C) 2010-2013 by Laurent Declercq
 * @author      Laurent Declercq <l.declercq@nuxwin.com>
 * @link        http://www.i-mscp.net i-MSCP Home Site
 * @license     http://www.gnu.org/licenses/gpl-2.0.html GPL v2
 */

/***********************************************************************************************************************
 * Functions
 */

/**
 * Add or update a mailing list
 *
 * @return boolean TRUE on success, FALSE otherwise
 */
function mailman_manageList()
{
	if (
		isset($_POST['list_id']) && isset($_POST['list_name']) && isset($_POST['admin_email']) &&
		isset($_POST['admin_password']) && isset($_POST['admin_password_confirm'])
	) {
		$error = false;
		$listId = clean_input($_POST['list_id']);
		$listName = clean_input($_POST['list_name']);
		$adminEmail = clean_input($_POST['admin_email']);
		$adminPassword = clean_input($_POST['admin_password']);
		$adminPasswordConfirm = clean_input($_POST['admin_password_confirm']);

		if (!preg_match('/[-_a-z0-9+]/i', $listName)) {
			set_page_message(tr("List name is not valid"), 'error');
			$error = true;
		}

		if (!chk_email($adminEmail)) {
			set_page_message(tr("Email is not valid"), 'error');
			$error = true;
		}

		if ($adminPassword != $adminPasswordConfirm) {
			set_page_message(tr("Passwords do not match"), 'error');
			$error = true;
		} elseif (!checkPasswordSyntax($adminPassword)) {
			$error = true;
		}

		if (!$error) {
			/** @var iMSCP_Config_Handler_File $cfg */
			$cfg = iMSCP_Registry::get('config');

			if ($listId === '-1') { // New email list
				try {
					$mainDmnProps = get_domain_default_props($_SESSION['user_id']);

					# Add email list data into the mailman table
					$query = '
						INSERT INTO `mailman` (
							`mailman_admin_id`, `mailman_admin_email`, `mailman_admin_password`, `mailman_list_name`,
							`mailman_status`
						) VALUES(
							?, ?, ?, ?, ?
						)
					';
					exec_query(
						$query,
						array(
							$mainDmnProps['domain_admin_id'], $adminEmail, $adminPassword, $listName,
							$cfg['ITEM_TOADD_STATUS']
						)
					);
				} catch (iMSCP_Exception_Database $e) {
					if ($e->getCode() == 23000) { // Duplicate entries
						set_page_message(
							tr("List %s already exists. Please choose other name.", $listName), 'warning'
						);

						return false;
					}
				}
			} else { // List update
				$query = '
					UPDATE
						`mailman`
					SET
						`mailman_admin_email` = ?, `mailman_admin_password` = ?, `mailman_status` = ?
					WHERE
						`mailman_id` = ?
					AND
						`mailman_admin_id` = ?
					AND
						`mailman_status` = ?
				';
				$stmt = exec_query(
					$query,
					array(
						$adminEmail, $adminPassword, $cfg->ITEM_TOCHANGE_STATUS, $listId, $_SESSION['user_id'],
						$cfg['ITEM_OK_STATUS']
					)
				);

				if (!$stmt->rowCount()) {
					showBadRequestErrorPage();
				}
			}

			// Send request to i-MSCP daemon
			send_request();

			return true;
		} else {
			return false;
		}
	} else {
		showBadRequestErrorPage();
		exit;
	}
}

/**
 * Delete the given mailing list
 *
 * @throws iMSCP_Exception_Database
 * @param int $listId Mailing list unique identifier
 * @return void
 */
function mailman_deleteList($listId)
{
	/** @var iMSCP_Config_Handler_File $cfg */
	$cfg = iMSCP_Registry::get('config');

	$mainDmnProps = get_domain_default_props($_SESSION['user_id']);

	$query = 'UPDATE`mailman` SET `mailman_status` = ? WHERE `mailman_id` = ? AND `mailman_admin_id` = ?';
	$stmt = exec_query($query, array($cfg['ITEM_TODELETE_STATUS'], $listId, $mainDmnProps['domain_admin_id']));

	if (!$stmt->rowCount()) {
		showBadRequestErrorPage();
	}

	// Send request to i-MSCP daemon
	send_request();
}

/**
 * Generate page.
 *
 * @param $tpl iMSCP_pTemplate
 * @return void
 */
function mailman_generatePage($tpl)
{
	/** @var iMSCP_Config_Handler_File $cfg */
	$cfg = iMSCP_Registry::get('config');

	$query = '
		SELECT
			`t1`.*, `t2`.`domain_name`
		FROM
			`mailman` AS `t1`
		INNER JOIN
			`domain` AS `t2` ON (`t2`.`domain_admin_id` = `t1`.`mailman_admin_id`)
		WHERE
			`t1`.`mailman_admin_id` = ?
		ORDER BY
			`t1`.`mailman_list_name`
	';
	$stmt = exec_query($query, $_SESSION['user_id']);
	$lists = $stmt->fetchAll(PDO::FETCH_UNIQUE | PDO::FETCH_ASSOC | PDO::FETCH_GROUP);

	if ($stmt->rowCount()) {
		foreach ($lists as $listId => $listData) {
			$tpl->assign(
				array(
					'LIST_URL' => "http://lists.{$listData['domain_name']}/admin/{$listData['mailman_list_name']}",
					'LIST_NAME' => tohtml($listData['mailman_list_name']),
					'ADMIN_EMAIL' => tohtml($listData['mailman_admin_email']),
					'ADMIN_PASSWORD' => '',
					'STATUS' => tohtml(translate_dmn_status($listData['mailman_status']))
				)
			);

			if ($listData['mailman_status'] == $cfg['ITEM_OK_STATUS']) {
				$tpl->assign(
					array(
						'EDIT_LINK' => "mailman.php?action=edit&list_id=$listId",
						'EDIT_ICON' => 'i_edit',
						'TR_EDIT' => tr('Edit'),
						'DELETE_LINK' => "mailman.php?action=edit&action=delete&list_id=$listId",
						'DELETE_ICON' => 'i_delete',
						'TR_DELETE' => tr('Delete')
					)
				);
			} else {
				$tpl->assign(
					array(
						'EDIT_LINK' => "#",
						'EDIT_ICON' => 'i_delete',
						'TR_EDIT' => tr('N/A'),
						'DELETE_LINK' => "#",
						'DELETE_ICON' => 'i_delete',
						'TR_DELETE' => tr('N/A')
					)
				);
			}

			$tpl->parse('EMAIL_LIST', '.email_list');
		}
	} else {
		$tpl->assign('EMAIL_LISTS', '');
		set_page_message(tr('You do not have created any mailing list.'), 'info');
	}

	if (isset($_REQUEST['action']) && $_REQUEST['action'] === 'edit') {
		$listId = clean_input($_REQUEST['list_id']);

		if (isset($lists[$listId])) {
			$listData = $lists[$listId];

			$tpl->assign(
				array(
					'LIST_DIALOG_OPEN' => 1,
					'LIST_NAME' => tohtml($listData['mailman_list_name']),
					'LIST_NAME_READONLY' => $cfg['HTML_READONLY'],
					'ADMIN_EMAIL' => tohtml($listData['mailman_admin_email']),
					'ADMIN_PASSWORD' => '',
					'ADMIN_PASSWORD_CONFIRM' => '',
					'LIST_ID' => tohtml($listId),
					'ACTION' => 'edit'
				)
			);
		} else {
			showBadRequestErrorPage();
		}
	} else {
		$tpl->assign(
			array(
				'LIST_DIALOG_OPEN' => isset($_REQUEST['list_name']) ? 1 : 0,
				'LIST_NAME' => isset($_REQUEST['list_name']) ? tohtml($_REQUEST['list_name']) : '',
				'LIST_NAME_READONLY' => '',
				'ADMIN_EMAIL' => isset($_REQUEST['admin_email']) ? tohtml($_REQUEST['admin_email']) : '',
				'ADMIN_PASSWORD' => '',
				'ADMIN_PASSWORD_CONFIRM' => '',
				'LIST_ID' => '-1',
				'ACTION' => 'add'
			)
		);
	}
}

/***********************************************************************************************************************
 * Main
 */

iMSCP_Events_Manager::getInstance()->dispatch(iMSCP_Events::onClientScriptStart);

check_login('user');

if (isset($_REQUEST['action'])) {
	$action = clean_input($_REQUEST['action']);

	if ($action == 'add') {
		if (mailman_manageList()) {
			set_page_message(tr('Mailing list successfully scheduled for addition'), 'success');
			redirectTo('mailman.php');
		}
	} elseif ($action == 'edit') {
		if (!empty($_POST) && mailman_manageList()) {
			set_page_message(tr('Mailing list successfully scheduled for update'), 'success');
			redirectTo('mailman.php');
		}
	} elseif ($action == 'delete' && isset($_REQUEST['list_id'])) {
		mailman_deleteList(clean_input($_REQUEST['list_id']));
		set_page_message(tr('Mailing list successfully scheduled for deletion'), 'success');
		redirectTo('mailman.php');
	} else {
		showBadRequestErrorPage();
	}
}

$tpl = new iMSCP_pTemplate();
$tpl->define_dynamic(
	array(
		'layout' => 'shared/layouts/ui.tpl',
		'page' => '../../plugins/Mailman/frontend/mailman.tpl',
		'page_message' => 'layout',
		'email_lists' => 'page',
		'email_list' => 'email_lists'
	)
);

$tpl->assign(
	array(
		'TR_PAGE_TITLE' => tr('Admin / Settings / Mailman'),
		'THEME_CHARSET' => tr('encoding'),
		'ISP_LOGO' => layout_getUserLogo(),
		'DATATABLE_TRANSLATIONS' => getDataTablesPluginTranslations(),
		'TR_MAIL_LISTS' => tojs(tr('Mailing List', false)),
		'TR_EDIT' => tr('Edit'),
		'TR_DELETE' => tr('Delete'),
		'TR_ADD_LIST' => tr('Add mailing list'),
		'TR_MAIL_LIST' => tr('Mailing List'),
		'TR_LIST_NAME' => tr('List name'),
		'TR_LIST_URL' => tr('List URL'),
		'TR_STATUS' => tr('Status'),
		'TR_ACTIONS' => tr('Actions'),
		'TR_ADMIN_EMAIL' => tr('Admin email'),
		'TR_ADMIN_PASSWORD' => tr('Password'),
		'TR_ADMIN_PASSWORD_CONFIRM' => tr('Password confirmation'),
		'TR_URL' => tr('Url'),
		'TR_CONFIRM_DELETION' => tr('Please, confirm deletion of the %s mailing list.', false, '%s'),
		'TR_APPLY' => tojs(tr('Apply', false)),
		'TR_CANCEL' => tojs(tr('Cancel', false))
	)
);

generateNavigation($tpl);
mailman_generatePage($tpl);
generatePageMessage($tpl);

$tpl->parse('LAYOUT_CONTENT', 'page');

iMSCP_Events_Manager::getInstance()->dispatch(iMSCP_Events::onClientScriptEnd, array('templateEngine' => $tpl));

$tpl->prnt();

unsetMessages();
