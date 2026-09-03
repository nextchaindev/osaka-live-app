import 'package:osaka_app/helpers/themes.dart';
import 'package:osaka_app/helpers/icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NoInternetWidget extends StatefulWidget {
  final void Function() reload;
  const NoInternetWidget({required this.reload, super.key});

  @override
  State<NoInternetWidget> createState() => _NoInternetWidgetState();
}

class _NoInternetWidgetState extends State<NoInternetWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.topCenter,
      height: double.infinity,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 200,
          ),
          SvgPicture.asset(
            Theme.of(context).colorScheme.noInternetIcon,
            width: perWidth(context, 216),
          ),
          SizedBox(
            height: 16,
          ),
          Text(
            'No internet connection',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
          ),
          Text(
            'Please check your internet connection and try again.',
            style: TextStyle(fontSize: 14, color: Color(0xff646464)),
          ),
          SizedBox(
            height: 16,
          ),
          TextButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              backgroundColor: Color(0xff5A4FF3),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(4), // Set your desired radius
              ),
              minimumSize: Size(100, 40),
            ),
            onPressed: () {
              widget.reload();
            },
            child: const Text(
              'Retry',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          )
        ],
      ),
    );
  }
}
