import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A端控制台',
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: const DialerScreen(),
    );
  }
}

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});
  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  String _inputNumber = '';
  String _statusText = '等待操作';
  bool _isBroadcasting = false;

  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  static const platform =
      MethodChannel('com.example.my_dialer_a/command_channel');

  final Map<String, String> _letters = {
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
    '0': '+'
  };

  @override
  void initState() {
    super.initState();
    // 监听原生悬浮窗发来的指令
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onNativeCommand') {
        String cmd = call.arguments as String;
        setState(() => _statusText = '执行指令: $cmd');
        // 如果想给 B 端发数据，可以在这里通过 _peripheral 的相关方法处理
      }
    });
  }

  // A端开启广播（等待 B 端搜索并连接）
  Future<void> _startBroadcasting() async {
    try {
      _peripheral.onDataReceived.listen((event) {
        // 收到 B 端发来的数据时的处理逻辑
        setState(() => _statusText = '收到 B 端数据');
      });

      await _peripheral.start(
        advertiseData: const AdvertiseDataCore(
          localName: "MyDialer_A",
          serviceUuid: "0000ffe0-0000-1000-8000-00805f9b34fb",
        ),
        gattServer: const GattServerSettings(),
      );

      setState(() {
        _isBroadcasting = true;
        _statusText = '蓝牙广播已开启，等待 B 端';
      });
    } catch (e) {
      setState(() => _statusText = '广播失败: $e');
    }
  }

  void _onNumberPress(String num) {
    setState(() => _inputNumber += num);
    if (_inputNumber == '999999999') {
      _inputNumber = '';
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('预留设置入口')));
    }
  }

  Future<void> _startFloatingWindow() async {
    try {
      await platform.invokeMethod('startFloatingWindow');
      setState(() => _statusText = '悬浮窗已开启');
    } catch (e) {
      setState(() => _statusText = '拉起悬浮窗失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部状态提示区
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(_statusText,
                  style: const TextStyle(color: Colors.blue, fontSize: 16)),
            ),

            // 号码显示
            Expanded(
              flex: 1,
              child: Container(
                alignment: Alignment.center,
                child: Text(_inputNumber,
                    style: const TextStyle(
                        fontSize: 40, color: Colors.white, letterSpacing: 2)),
              ),
            ),

            // 拨号键盘
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildRow(['1', '2', '3']),
                    _buildRow(['4', '5', '6']),
                    _buildRow(['7', '8', '9']),
                    _buildRow(['*', '0', '#']),
                  ],
                ),
              ),
            ),

            // 底部操作区
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 拉起悬浮窗按钮
                  GestureDetector(
                    onTap: _startFloatingWindow,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.layers,
                          color: Colors.blue, size: 32),
                    ),
                  ),

                  // 中间绿色按钮：开启蓝牙广播
                  GestureDetector(
                    onTap: _isBroadcasting ? null : _startBroadcasting,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                          color: _isBroadcasting
                              ? Colors.grey
                              : const Color(0xFF34C759),
                          shape: BoxShape.circle),
                      child: Icon(
                          _isBroadcasting
                              ? Icons.bluetooth_searching
                              : Icons.bluetooth,
                          color: Colors.white,
                          size: 32),
                    ),
                  ),

                  // 退格键
                  GestureDetector(
                    onTap: () {
                      if (_inputNumber.isNotEmpty) {
                        setState(() => _inputNumber =
                            _inputNumber.substring(0, _inputNumber.length - 1));
                      }
                    },
                    child: Container(
                      width: 70,
                      alignment: Alignment.center,
                      child: _inputNumber.isNotEmpty
                          ? const Icon(Icons.backspace_outlined,
                              color: Colors.white, size: 28)
                          : const SizedBox(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKey(key)).toList(),
    );
  }

  Widget _buildKey(String key) {
    String letter = _letters[key] ?? '';
    return GestureDetector(
      onTap: () => _onNumberPress(key),
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
            color: const Color(0xFF333333),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)
            ]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(key,
                style: const TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.w400)),
            if (letter.isNotEmpty)
              Text(letter,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}
