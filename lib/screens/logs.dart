// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:droid_hole/widgets/no_server_selected.dart';
import 'package:droid_hole/widgets/logs_filters_modal.dart';
import 'package:droid_hole/widgets/log_status.dart';
import 'package:droid_hole/widgets/log_details_modal.dart';
import 'package:droid_hole/widgets/custom_radio.dart';
import 'package:droid_hole/widgets/selected_server_disconnected.dart';

import 'package:droid_hole/classes/no_scroll_behavior.dart';
import 'package:droid_hole/constants/log_status.dart';
import 'package:droid_hole/providers/filters_provider.dart';
import 'package:droid_hole/classes/process_modal.dart';
import 'package:droid_hole/functions/format.dart';
import 'package:droid_hole/models/log.dart';
import 'package:droid_hole/services/http_requests.dart';
import 'package:droid_hole/providers/servers_provider.dart';
import 'package:droid_hole/models/server.dart';

class Logs extends StatelessWidget {
  const Logs({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final filtersProvider = Provider.of<FiltersProvider>(context);

    final statusBarHeight = MediaQuery.of(context).viewPadding.top;

    if (serversProvider.selectedServer != null && serversProvider.isServerConnected == true) {
      return LogsList(
        server: serversProvider.selectedServer!, 
        token: serversProvider.selectedServerToken!['phpSessId'],
        selectedStatus: filtersProvider.statusSelected,
        startTime: filtersProvider.startTime,
        endTime: filtersProvider.endTime,
      ); 
    }
    else {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size(double.maxFinite, 70),
          child: Container(
            margin: EdgeInsets.only(top: statusBarHeight),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor
                )
              )
            ),
            child: Text(
              AppLocalizations.of(context)!.queryLogs,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20
              ),
            ),
          )
        ),
        body: serversProvider.selectedServer != null 
        ? serversProvider.isServerConnected == true 
          ? null
          : const Center(
              child: SelectedServerDisconnected()
            )
        : const NoServerSelected()
      );
    }
  }
}

class LogsList extends StatefulWidget {
  final Server server;
  final String token;
  final List<int> selectedStatus;
  final DateTime? startTime;
  final DateTime? endTime;

  const LogsList({
    Key? key,
    required this.server,
    required this.token,
    required this.selectedStatus,
    required this.startTime,
    required this.endTime,
  }) : super(key: key);

  @override
  State<LogsList> createState() => _LogsListState();
}

class _LogsListState extends State<LogsList> {
  DateTime? _lastTimestamp;
  bool _isLoadingMore = false;

  late ScrollController _scrollController;

  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();

  int loadStatus = 0;
  List<Log> logsList = [];
  int sortStatus = 0;

  DateTime? masterStartTime;
  DateTime? masterEndTime;

  Future loadLogs({
    List<int>? statusSelected,
    DateTime? inStartTime,
    DateTime? inEndTime, 
    required bool replaceOldLogs,
  }) async {
    DateTime? startTime = masterStartTime ?? inStartTime;
    DateTime? endTime = masterEndTime ?? inEndTime;
    late DateTime? timestamp;
    late DateTime? minusHoursTimestamp;
    if (replaceOldLogs == true) {
      _lastTimestamp = null;
    }
    if (_lastTimestamp == null || replaceOldLogs == true) {
      final now = DateTime.now();
      timestamp = endTime ?? now;
      DateTime newOldTimestamp = DateTime(timestamp.year, timestamp.month, timestamp.day, timestamp.hour-2, timestamp.minute, timestamp.second);
      if (startTime != null) {
        minusHoursTimestamp = newOldTimestamp.isAfter(startTime) ? newOldTimestamp : startTime;
      }
      else {
        minusHoursTimestamp = newOldTimestamp;
      }
    }
    else {
      timestamp = _lastTimestamp!;
      DateTime newOldTimestamp = DateTime(_lastTimestamp!.year, _lastTimestamp!.month, _lastTimestamp!.day, _lastTimestamp!.hour-2, _lastTimestamp!.minute, _lastTimestamp!.second);
      if (startTime != null) {
        minusHoursTimestamp = newOldTimestamp.isAfter(startTime) ? newOldTimestamp : startTime;
      }
      else {
        minusHoursTimestamp = newOldTimestamp;
      }
    }
    if (startTime != null && minusHoursTimestamp.isBefore(startTime)) {
      _isLoadingMore = false;
      setState(() => loadStatus = 1);
    }
    else {
      final result = await fetchLogs(
        server: widget.server,
        phpSessId: widget.token,
        from:  minusHoursTimestamp,
        until: timestamp
      );
      _isLoadingMore = false;
      if (result['result'] == 'success') {
        List<Log> items = [];
        result['data'].forEach((item) => items.add(Log.fromJson(item)));
        if (replaceOldLogs == true) {
          setState(() {
            loadStatus = 1;
            logsList = items.reversed.toList();
            _lastTimestamp = minusHoursTimestamp;
          });
        }
        else {
          setState(() {
            loadStatus = 1;
            logsList = logsList+items.reversed.toList();
            _lastTimestamp = minusHoursTimestamp;
          });
        }
      }
      else {
        setState(() => loadStatus = 2);
      }
    }
  }

  List<Log> filterLogs({
    List<Log>? logs,
    required List<int> statusSelected,
    required List<String> devicesSelected,
  }) {
    List<Log> tempLogs = logs != null ? [...logs] : [...logsList];

    tempLogs = tempLogs.where((log) {
      if (statusSelected.contains(int.parse(log.status))) {
        return true;
      }
      else {
        return false;
      }
    }).toList();

    if (devicesSelected.isNotEmpty) {
      tempLogs = tempLogs.where((log) {
        if (devicesSelected.contains(log.device)) {
          return true;
        }
        else {
          return false;
        }
      }).toList();
    }

    if (_searchController.text != '') {
      tempLogs = tempLogs.where((log) {
        if (log.url.contains(_searchController.text)) {
          return true;
        }
        else {
          return false;
        }
      }).toList();
    }

    if (sortStatus == 1) {
      tempLogs.sort((a,b) => a.dateTime.compareTo(b.dateTime));
    }
    else {
      tempLogs.sort((a,b) => a.dateTime.compareTo(b.dateTime));
      tempLogs = tempLogs.reversed.toList();
    }

    return tempLogs;
  } 


  void _scrollListener() {
    if (_scrollController.position.extentAfter < 500 && _isLoadingMore == false) {
      _isLoadingMore = true;
      loadLogs(replaceOldLogs: false);
    }
  }


  @override
  void initState() {
    _scrollController = ScrollController()..addListener(_scrollListener);
    loadLogs(replaceOldLogs: true);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final serversProvider = Provider.of<ServersProvider>(context);
    final filtersProvider = Provider.of<FiltersProvider>(context);

    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).viewPadding.top;   
    final bottomNavBarHeight = MediaQuery.of(context).viewPadding.bottom;   

    List<Log> logsListDisplay = filterLogs(
      statusSelected: filtersProvider.statusSelected, 
      devicesSelected: filtersProvider.selectedClients
    );

    void _updateSortStatus(value) {
      if (sortStatus != value) {
        _scrollController.animateTo(
          0, 
          duration: const Duration(milliseconds: 250), 
          curve: Curves.easeInOut
        );
        setState(() {
          sortStatus = value;
          logsListDisplay = logsListDisplay.reversed.toList();
        });
      }
    }

    void _whiteBlackList(String list, Log log) async {
      final loading = ProcessModal(context: context);
      loading.open(
        list == 'white' 
          ? AppLocalizations.of(context)!.addingWhitelist
          : AppLocalizations.of(context)!.addingBlacklist,
      );
      final result = await setWhiteBlacklist(
        server: serversProvider.selectedServer!, 
        domain: log.url, 
        list: list, 
        token: serversProvider.selectedServerToken!['token'], 
        phpSessId: serversProvider.selectedServerToken!['phpSessId']
      );
      loading.close();
      if (result['result'] == 'success') {
        if (result['data']['message'].toString().contains('Added')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                list == 'white'
                  ? AppLocalizations.of(context)!.addedWhitelist
                  : AppLocalizations.of(context)!.addedBlacklist,
              ),
              backgroundColor: Colors.green,
            )
          );
        }
        else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                list == 'white'
                  ? AppLocalizations.of(context)!.alreadyWhitelist
                  : AppLocalizations.of(context)!.alreadyBlacklist,
              ),
              backgroundColor: Colors.grey,
            )
          );
        }
      }
      else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              list == 'white'
                ? AppLocalizations.of(context)!.couldntAddWhitelist
                : AppLocalizations.of(context)!.couldntAddBlacklist,
            ),
            backgroundColor: Colors.red,
          )
        );
      }
    }

    void _showLogDetails(Log log) {
      showModalBottomSheet(
        context: context, 
        builder: (context) => LogDetailsModal(
          log: log,
          statusBarHeight: statusBarHeight,
          whiteBlackList: _whiteBlackList,
        ),
        backgroundColor: Colors.transparent,
        isDismissible: true, 
        enableDrag: true,
        isScrollControlled: true,
      );
    }

    void _showFiltersModal() {
      showModalBottomSheet(
        context: context, 
        builder: (context) => LogsFiltersModal(
          statusBarHeight: statusBarHeight,
          bottomNavBarHeight: bottomNavBarHeight,
          filterLogs: () {
            setState(() {
              masterStartTime = filtersProvider.startTime;
              masterEndTime = filtersProvider.endTime;
              loadStatus = 0;
            });
            loadLogs(
              replaceOldLogs: true,
              inStartTime: filtersProvider.startTime,
              inEndTime: filtersProvider.endTime
            );
          },
        ),
        backgroundColor: Colors.transparent,
        isDismissible: true, 
        enableDrag: true,
        isScrollControlled: true,
      );
    }

    void _searchLogs(String value) {
      List<Log> searched = logsList.where((log) => 
        log.url.toLowerCase().contains(value.toLowerCase())
      ).toList();
      setState(() {
        logsListDisplay = searched;
      });
      filtersProvider.resetFilters();
    }

    Widget _status() {
      switch (loadStatus) {
        case 0:
          return SizedBox(
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 50),
                Text(
                  AppLocalizations.of(context)!.loadingLogs,
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold
                  ),
                )
              ],
            ),
          );
        case 1:
          return RefreshIndicator(
            onRefresh: (() async {
              _lastTimestamp = DateTime.now();
              await loadLogs(replaceOldLogs: true);
            }),
            child: logsListDisplay.isNotEmpty
              ? ListView.builder(
                  controller: _scrollController,
                  itemCount: _isLoadingMore == true 
                    ? logsListDisplay.length+1
                    : logsListDisplay.length,
                  itemBuilder: (context, index) {
                    if (_isLoadingMore == true && index == logsListDisplay.length-1) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    else {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showLogDetails(logsListDisplay[index]),
                          child: Container(
                            width: double.maxFinite,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: index < logsListDisplay.length
                                ? Border(
                                    bottom: BorderSide(
                                      color: Theme.of(context).dividerColor
                                    )
                                  )
                                : null
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LogStatus(status: logsListDisplay[index].status, showIcon: true),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: width-100,
                                      child: Text(
                                        logsListDisplay[index].url,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: width-100,
                                      child: Text(
                                        logsListDisplay[index].device,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                                Text(
                                  formatTimestamp(logsListDisplay[index].dateTime, 'HH:mm:ss')
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                  }
                )
              : ScrollConfiguration(
                  behavior: NoScrollBehavior(),
                  child: ListView(
                    children: [
                      SizedBox(
                        height: height-144,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [ 
                              Text(
                                AppLocalizations.of(context)!.noLogsDisplay,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    ]
                  ),
                )
          );

        case 2:
          return SizedBox(
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error,
                  size: 50,
                  color: Colors.red,
                ),
                const SizedBox(height: 50),
                Text(
                  AppLocalizations.of(context)!.couldntLoadLogs,
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold
                  ),
                )
              ],
            ),
          );
          
        default:
          return const SizedBox();
      }
    }

    Widget _buildChip(String label, Icon icon, Function() onDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Chip(
          label: Text(label),
          avatar: icon,
          deleteIcon: const Icon(
            Icons.cancel,
            size: 18,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          onDeleted: onDeleted,
        ),
      );
    }

    bool _areFiltersApplied() {
      if (
        filtersProvider.statusSelected.length < 13 ||
        filtersProvider.startTime != null ||
        filtersProvider.endTime != null ||
        filtersProvider.selectedClients.length < filtersProvider.totalClients.length
      ) {
        return true;
      }
      else {
        return false;
      }
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size(double.maxFinite, _areFiltersApplied() == true ? 110 : 60),
        child: Container(
          margin: EdgeInsets.only(top: statusBarHeight),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor
                )
              )
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  child: _showSearchBar == false
                    ? Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 10
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 20,
                              bottom: 15
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.queryLogs,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showSearchBar = true;
                                  });
                                }, 
                                icon: const Icon(Icons.search_rounded),
                                splashRadius: 20,
                              ),
                              IconButton(
                                onPressed: _showFiltersModal, 
                                icon: const Icon(Icons.filter_list_rounded),
                                splashRadius: 20,
                              ),
                              PopupMenuButton(
                                splashRadius: 20,
                                icon: const Icon(Icons.sort_rounded),
                                onSelected: (value) => _updateSortStatus(value),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 0,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.arrow_downward_rounded),
                                            const SizedBox(width: 15),
                                            Text(AppLocalizations.of(context)!.fromLatestToOldest),
                                          ],
                                        ),
                                        CustomRadio(
                                          value: 0, 
                                          groupValue: sortStatus, 
                                        )
                                      ],
                                    )
                                  ),
                                  PopupMenuItem(
                                    value: 1,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.arrow_upward_rounded),
                                            const SizedBox(width: 15),
                                            Text(AppLocalizations.of(context)!.fromOldestToLatest),
                                          ],
                                        ),
                                        CustomRadio(
                                          value: 1, 
                                          groupValue: sortStatus, 
                                        )
                                      ],
                                    )
                                  ),
                                ]
                              )
                            ],
                          )
                        ]
                      ),
                    )
                  : SizedBox(
                    height: 59,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showSearchBar = false;
                              _searchController.text = "";
                            });
                            _scrollController.animateTo(
                              0, 
                              duration: const Duration(milliseconds: 250), 
                              curve: Curves.easeInOut
                            );
                          },
                          icon: const Icon(Icons.arrow_back),
                          splashRadius: 20,
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: width-116,
                          height: 50,
                          child: TextField(
                            controller: _searchController,
                            onChanged: _searchLogs,
                            style: const TextStyle(
                              fontSize: 18
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: AppLocalizations.of(context)!.searchUrl,
                              hintStyle: const TextStyle(
                                fontSize: 18
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: () {
                            setState(() => _searchController.text = "");
                            _scrollController.animateTo(
                              0, 
                              duration: const Duration(milliseconds: 250), 
                              curve: Curves.easeInOut
                            );
                          }, 
                          icon: const Icon(Icons.clear_rounded),
                          splashRadius: 20,
                          color: Colors.black,
                        )
                      ],
                    ),
                  ),
                ),
                if (_areFiltersApplied() == true) Container(
                    width: double.maxFinite,
                    height: 50,
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        const SizedBox(width: 5),
                        if (filtersProvider.startTime != null || filtersProvider.endTime != null) _buildChip(
                          AppLocalizations.of(context)!.time, 
                          const Icon(Icons.access_time_rounded),
                          () {
                            filtersProvider.resetTime();
                            setState(() {
                              loadStatus = 0;
                            });
                            loadLogs(replaceOldLogs: true);
                          }
                        ),
                        if (filtersProvider.statusSelected.length < 13) _buildChip(
                          filtersProvider.statusSelected.length == 1
                            ? logStatusString[filtersProvider.statusSelected[0]-1]
                            : "${filtersProvider.statusSelected.length} ${AppLocalizations.of(context)!.statusSelected}",
                          const Icon(Icons.shield),
                          () => filtersProvider.resetStatus(),
                        ),
                        if (filtersProvider.selectedClients.isNotEmpty && filtersProvider.selectedClients.length < filtersProvider.totalClients.length) _buildChip(
                          filtersProvider.selectedClients.length == 1
                            ? filtersProvider.selectedClients[0]
                            : "${filtersProvider.selectedClients.length} ${AppLocalizations.of(context)!.clientsSelected}",
                          const Icon(Icons.devices),
                          () => filtersProvider.resetClients(),
                        ),
                        const SizedBox(width: 5),
                      ],
                    )
                  )
              ],
            ),
          )
        )
      ),
      body: _status()
    );
  }
}