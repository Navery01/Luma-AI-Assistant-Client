import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';


class RadialHomePage extends StatefulWidget {
  const RadialHomePage({super.key});

  @override
  State<RadialHomePage> createState() => _RadialHomePageState();
}

class _RadialHomePageState extends State<RadialHomePage>{

  late final RiveWidgetController _riveController;
  late final ViewModelInstance vm;
  var isRiveLoaded = false;
  
  @override
  void initState() {
    super.initState();
    _loadRive();
  }

  @override
  void dispose() {
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    _updateViewModel();
    return isRiveLoaded ? RiveWidget(
      controller: _riveController,
      fit: Fit.cover,
    ) : const Center(child: CircularProgressIndicator(),);
}

void _loadRive() async {
  ByteData fileBytes = await rootBundle.load('assets/anim/homecontrollinterface.riv');
  final riveFile = await File.decode(fileBytes.buffer.asUint8List(), riveFactory: Factory.rive);
  _riveController = RiveWidgetController(
    stateMachineSelector: StateMachineSelector.byName("State Machine 1"),
    artboardSelector: ArtboardSelector.byName("root"),
    riveFile!,
  );

  vm = _riveController.dataBind(DataBind.auto());

  setState(() {
    isRiveLoaded = true;

  });

}

void _updateViewModel() {
  if (isRiveLoaded) {
    var now = DateTime.now().toLocal();
    var shortDate = DateFormat('MMM dd').format(now);
    var shortTime = DateFormat('hh:mm').format(now);
    
    vm.string("date")!.value = shortDate;
    vm.string("currentTime")!.value = shortTime;
    vm.string("temperature")!.value = "72°";
    debugPrint(vm.properties.toString());
  }
}

void _onRiveLoaded(){
  
}

}


