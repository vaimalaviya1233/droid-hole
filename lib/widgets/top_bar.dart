import 'package:flutter/material.dart';
import 'package:flutter_web_browser/flutter_web_browser.dart';
import 'package:provider/provider.dart';

import 'package:droid_hole/widgets/servers_list_modal.dart';

import 'package:droid_hole/services/http_requests.dart';
import 'package:droid_hole/models/process_modal.dart';
import 'package:droid_hole/providers/servers_provider.dart';

class TopBar extends StatelessWidget {
  const TopBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);

    final statusBarHeight = MediaQuery.of(context).viewPadding.top;

    void _openWebPanel() {
      if (serversProvider.isServerConnected == true) {
        FlutterWebBrowser.openWebPage(
          url: '${serversProvider.connectedServer!.address}/admin/',
          customTabsOptions: const CustomTabsOptions(
            instantAppsEnabled: true,
            showTitle: true,
            urlBarHidingEnabled: false,
          ),
          safariVCOptions: const SafariViewControllerOptions(
            barCollapsingEnabled: true,
            dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
            modalPresentationCapturesStatusBarAppearance: true,
          )
        );
      }
    }

    void _refresh() async {
      if (serversProvider.isServerConnected  == true) {
        final ProcessModal process = ProcessModal(context: context);
        process.open("Refreshing data...");
        final result = await realtimeStatus(serversProvider.connectedServer!);
        // ignore: use_build_context_synchronously
        process.close();
        if (result['result'] == "success") {
          serversProvider.updateConnectedServerStatus(
            result['data'].status == 'enabled' ? true : false
          );
          serversProvider.setRealtimeStatus(result['data']);
        }
        else {
          serversProvider.setIsServerConnected(false);
          if (serversProvider.getStatusLoading == 0) {
            serversProvider.setStatusLoading(2);
          }
        }
      }
    }

    void _changeServer() {
      Future.delayed(const Duration(seconds: 0), () => {
        showModalBottomSheet(
          context: context, 
          builder: (context) => const ServersListModal(),
          backgroundColor: Colors.transparent,
          isDismissible: false,
          enableDrag: false
        )
      });
    }

    return Container(
      padding: const EdgeInsets.all(20),
      margin: EdgeInsets.only(top: statusBarHeight),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.black12
          )
        )
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: serversProvider.connectedServer != null 
              ? [
                  Icon(
                    serversProvider.connectedServer!.enabled == true 
                      ? Icons.verified_user_rounded
                      : Icons.gpp_bad_rounded,
                    size: 35,
                    color: serversProvider.connectedServer!.enabled == true
                      ? Colors.green
                      : Colors.red,
                  ),
                  const SizedBox(width: 20),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (serversProvider.connectedServer!.alias != null) Text(
                        serversProvider.connectedServer!.alias!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 25
                        ),
                      ),
                      Text(
                        serversProvider.connectedServer!.address,
                        style: serversProvider.connectedServer!.alias != null
                          ? const TextStyle(
                            fontSize: 16,
                            color: Colors.grey
                            )
                          : const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 25
                            ),
                      )
                    ],
                  ),
                ]
              : const [
                Icon(
                  Icons.shield,
                  color: Colors.grey,
                  size: 35,
                ),
                SizedBox(width: 20),
                Text(
                  "No server is selected",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 25
                  ),
                ),
              ]
          ),
          PopupMenuButton(
            splashRadius: 20,
            itemBuilder: (context) => 
              serversProvider.connectedServer != null 
                ? serversProvider.isServerConnected == true 
                  ? [
                      PopupMenuItem(
                        onTap: _refresh,
                        child: Row(
                          children: const [
                            Icon(Icons.refresh),
                            SizedBox(width: 15),
                            Text("Refresh")
                          ],
                        )
                      ),
                      PopupMenuItem(
                        onTap: _openWebPanel,
                        child: Row(
                          children: const [
                            Icon(Icons.web),
                            SizedBox(width: 15),
                            Text("Open web panel")
                          ],
                        )
                      ),
                      PopupMenuItem(
                        onTap: _changeServer,
                        child: Row(
                          children: const [
                            Icon(Icons.storage_rounded),
                            SizedBox(width: 15),
                            Text("Change Server")
                          ],
                        )
                      ),
                    ]
                  : [
                    PopupMenuItem(
                      onTap: () => {},
                      child: Row(
                        children: const [
                          Icon(Icons.refresh_rounded),
                          SizedBox(width: 15),
                          Text("Try reconnect")
                        ],
                      )
                    ),
                  ]
                : [
                  PopupMenuItem(
                    onTap: _changeServer,
                    child: Row(
                      children: const [
                        Icon(Icons.storage_rounded),
                        SizedBox(width: 15),
                        Text("Select Server")
                      ],
                    )
                  ),
                ]
          )
        ],
      ),
    );
  }
}