// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:droid_hole/widgets/reset_modal.dart';
import 'package:droid_hole/widgets/custom_list_tile.dart';

import 'package:droid_hole/config/system_overlay_style.dart';
import 'package:droid_hole/providers/servers_provider.dart';
import 'package:droid_hole/classes/process_modal.dart';
import 'package:droid_hole/providers/app_config_provider.dart';

class AdvancedOptions extends StatelessWidget {
  const AdvancedOptions({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final appConfigProvider = Provider.of<AppConfigProvider>(context);

    void _updateSslCheck(bool newStatus) async {
      final result = await appConfigProvider.setOverrideSslCheck(newStatus);
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.restartAppTakeEffect),
            backgroundColor: Colors.green,
          )
        );
      }
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cannotUpdateSettings),
            backgroundColor: Colors.red,
          )
        );
      }
    }

    void _updateOneColumnLegend(bool newStatus) async {
      final result = await appConfigProvider.setOneColumnLegend(newStatus);
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.settingsUpdatedSuccessfully),
            backgroundColor: Colors.green,
          )
        );
      }
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cannotUpdateSettings),
            backgroundColor: Colors.red,
          )
        );
      }
    }

    void _updateUseReducedData(bool newStatus) async {
      final result = await appConfigProvider.setReducedDataCharts(newStatus);
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.settingsUpdatedSuccessfully),
            backgroundColor: Colors.green,
          )
        );
      }
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.cannotUpdateSettings),
            backgroundColor: Colors.red,
          )
        );
      }
    }

    void _deleteApplicationData() async {
      final ProcessModal process = ProcessModal(context: context);
      process.open(AppLocalizations.of(context)!.deleting);
      await serversProvider.deleteDbData();
      await appConfigProvider.restoreAppConfig();
      process.close();
      Phoenix.rebirth(context);
    }

    void _openResetModal() {
      showDialog(
        context: context, 
        builder: (context) => ResetModal(
          onConfirm: _deleteApplicationData,
        ),
        useSafeArea: true
      );
    }

    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: systemUiOverlayStyleConfig(context),
        title: Text(AppLocalizations.of(context)!.advancedSetup),
      ),
      body: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(25),
                child: Text(
                  AppLocalizations.of(context)!.security,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16
                  ),
                ),
              ),
            ],
          ),
          CustomListTile(
            leadingIcon: Icons.lock,
            label: AppLocalizations.of(context)!.dontCheckCertificate,
            description: AppLocalizations.of(context)!.dontCheckCertificateDescription,
            trailing: Switch(
              value: appConfigProvider.overrideSslCheck, 
              onChanged: _updateSslCheck,
              activeColor: Theme.of(context).primaryColor,
            ),
            onTap: () => _updateSslCheck(!appConfigProvider.overrideSslCheck),
            padding: const EdgeInsets.only(
              top: 10,
              bottom: 10,
              left: 20,
              right: 10
            )
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor
                )
              )
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(25),
                child: Text(
                  AppLocalizations.of(context)!.charts,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16
                  ),
                ),
              ),
            ],
          ),
          CustomListTile(
            leadingIcon: Icons.list,
            label: AppLocalizations.of(context)!.oneColumnLegend,
            description: AppLocalizations.of(context)!.oneColumnLegendDescription,
            onTap: () => _updateOneColumnLegend(!appConfigProvider.oneColumnLegend),
            padding: const EdgeInsets.only(
              top: 10,
              bottom: 10,
              left: 20,
              right: 10
            ),
            trailing: Switch(
              value: appConfigProvider.oneColumnLegend, 
              onChanged: _updateOneColumnLegend,
              activeColor: Theme.of(context).primaryColor,
            ),
          ),
          CustomListTile(
            leadingIcon: Icons.stacked_line_chart_rounded,
            label: AppLocalizations.of(context)!.reducedDataCharts,
            description: AppLocalizations.of(context)!.reducedDataChartsDescription,
            onTap: () => _updateUseReducedData(!appConfigProvider.reducedDataCharts),
            padding: const EdgeInsets.only(
              top: 10,
              bottom: 10,
              left: 20,
              right: 10
            ),
            trailing: Switch(
              value: appConfigProvider.reducedDataCharts, 
              onChanged: _updateUseReducedData,
              activeColor: Theme.of(context).primaryColor,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor
                )
              )
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(25),
                child: Text(
                  AppLocalizations.of(context)!.others,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16
                  ),
                ),
              ),
            ],
          ),
          CustomListTile(
            leadingIcon: Icons.delete,
            label: AppLocalizations.of(context)!.resetApplication, 
            description: AppLocalizations.of(context)!.erasesAppData,
            color: Colors.red,
            onTap: _openResetModal,
            padding: const EdgeInsets.only(
              top: 10,
              bottom: 10,
              left: 20,
              right: 10
            )
          )
        ],
      ),
    );
  }
}