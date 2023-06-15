import 'dart:async';
import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:emartdriver/Parcel_service/parcel_images_show.dart';
import 'package:emartdriver/Parcel_service/parcel_order_model.dart';
import 'package:emartdriver/constants.dart';
import 'package:emartdriver/main.dart';
import 'package:emartdriver/model/CurrencyModel.dart';
import 'package:emartdriver/model/User.dart';
import 'package:emartdriver/services/FirebaseHelper.dart';
import 'package:emartdriver/services/helper.dart';
import 'package:emartdriver/ui/chat_screen/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart' as UrlLauncher;

class ParcelHomeScreen extends StatefulWidget {
  final VoidCallback refresh;

  const ParcelHomeScreen({Key? key, required this.refresh}) : super(key: key);

  @override
  State<ParcelHomeScreen> createState() => _ParcelHomeScreenState();
}

class _ParcelHomeScreenState extends State<ParcelHomeScreen> with SingleTickerProviderStateMixin {
  final fireStoreUtils = FireStoreUtils();

  GoogleMapController? _mapController;
  bool canShowSheet = true;

  BitmapDescriptor? departureIcon;
  BitmapDescriptor? destinationIcon;
  BitmapDescriptor? taxiIcon;

  Map<PolylineId, Polyline> polyLines = {};
  PolylinePoints polylinePoints = PolylinePoints();
  final Map<String, Marker> _markers = {};

  setIcons() async {
    BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(
              size: Size(10, 10),
            ),
            "assets/images/pickup.png")
        .then((value) {
      departureIcon = value;
    });

    BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(
              size: Size(10, 10),
            ),
            "assets/images/dropoff.png")
        .then((value) {
      destinationIcon = value;
    });

    BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(
              size: Size(10, 10),
            ),
            "assets/images/ic_taxi.png")
        .then((value) {
      taxiIcon = value;
    });
  }

  Timer? _timer;

  void startTimer(User _driverModel) {
    const oneSec = const Duration(seconds: 1);
    _timer = new Timer.periodic(
      oneSec,
      (Timer timer) async {
        if (driverOrderAcceptRejectDuration == 0) {
          timer.cancel();
          if (_driverModel.ordercabRequestData != null) {
            await rejectOrder(_driverModel);
            Navigator.pop(context);
          }
        } else {
            driverOrderAcceptRejectDuration--;
        }
      },
    );
  }

  updateDriverOrder() async {
    Timestamp startTimestamp = Timestamp.now();
    Timestamp endTimestamp = Timestamp.now();

    DateTime currentDate = startTimestamp.toDate();
    currentDate = currentDate.subtract(Duration(hours: 3));
    startTimestamp = Timestamp.fromDate(currentDate);

    List<ParcelOrderModel> orders = [];

    print('-->startTime${startTimestamp.toDate()}');
    print('-->endTime${endTimestamp.toDate()}');
    await FirebaseFirestore.instance
        .collection(PARCELORDER)
        .where('status', whereIn: [ORDER_STATUS_PLACED, ORDER_STATUS_DRIVER_REJECTED])
        .where('senderPickupDateTime', isGreaterThan: startTimestamp)
        .where('senderPickupDateTime', isLessThan: endTimestamp)
        .get()
        .then((value) async {
          print('---->${value.docs.length}');
          await Future.forEach(value.docs, (QueryDocumentSnapshot<Map<String, dynamic>> element) {
            try {
              orders.add(ParcelOrderModel.fromJson(element.data()));
            } catch (e, s) {
              print('watchOrdersStatus parse error ${element.id}$e $s');
            }
          });
        });

    orders.forEach((element) {
      ParcelOrderModel orderModel = element;
      print('---->${orderModel.id}');
      orderModel.trigger_delevery = Timestamp.now();
      orderModel.sendToDriver = true;
      FirebaseFirestore.instance.collection(PARCELORDER).doc(element.id).set(orderModel.toJson(), SetOptions(merge: true)).then((order) {
        print('Done.');
      });
    });
  }

  AnimationController? _animationController;

  @override
  void initState() {
    getDriver();
    setIcons();
    super.initState();

    _animationController = new AnimationController(vsync: this, duration: Duration(seconds: 1));
    _animationController!.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController!.dispose();

    FireStoreUtils().parcelOrdersStreamController.close();
    FireStoreUtils().parcelOrdersStreamSub.cancel();
    if (_timer != null) {
      _timer!.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    isDarkMode(context)
        ? _mapController?.setMapStyle('[{"featureType": "all","'
            'elementType": "'
            'geo'
            'met'
            'ry","stylers": [{"color": "#242f3e"}]},{"featureType": "all","elementType": "labels.text.stroke","stylers": [{"lightness": -80}]},{"featureType": "administrative","elementType": "labels.text.fill","stylers": [{"color": "#746855"}]},{"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#263c3f"}]},{"featureType": "poi.park","elementType": "labels.text.fill","stylers": [{"color": "#6b9a76"}]},{"featureType": "road","elementType": "geometry.fill","stylers": [{"color": "#2b3544"}]},{"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#9ca5b3"}]},{"featureType": "road.arterial","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.arterial","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "road.highway","elementType": "geometry.fill","stylers": [{"color": "#746855"}]},{"featureType": "road.highway","elementType": "geometry.stroke","stylers": [{"color": "#1f2835"}]},{"featureType": "road.highway","elementType": "labels.text.fill","stylers": [{"color": "#f3d19c"}]},{"featureType": "road.local","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.local","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "transit","elementType": "geometry","stylers": [{"color": "#2f3948"}]},{"featureType": "transit.station","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "water","elementType": "geometry","stylers": [{"color": "#17263c"}]},{"featureType": "water","elementType": "labels.text.fill","stylers": [{"color": "#515c6d"}]},{"featureType": "water","elementType": "labels.text.stroke","stylers": [{"lightness": -20}]}]')
        : _mapController?.setMapStyle(null);

    return Scaffold(
      body: _driverModel!.isActive
          ? Stack(
              alignment: Alignment.bottomCenter,
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  mapType: MapType.normal,
                  zoomControlsEnabled: false,
                  polylines: Set<Polyline>.of(polyLines.values),
                  markers: _markers.values.toSet(),
                  padding: EdgeInsets.only(
                    top: 40.0,
                  ),
                  initialCameraPosition: CameraPosition(
                    zoom: 15,
                    target: LatLng(_driverModel!.location.latitude, _driverModel!.location.longitude),
                  ),
                ),
                Visibility(
                  visible: _driverModel!.inProgressOrderID == null,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      color: Colors.black,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("You have to minimum $symbol ${double.parse(minimumDepositToRideAccept.toString()).toStringAsFixed(decimal)} wallet amount to receiving Order",
                            style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ),
                if (_driverModel!.inProgressOrderID != null && currentOrder != null) buildOrderActionsCard()
              ],
            )
          : Center(
              child: showEmptyState('You are offline'.tr(),
                  description: 'Go online in order to start getting delivery requests from customers and vendors.'.tr(),
                  isDarkMode: isDarkMode(context),
                  buttonTitle: 'Go Online'.tr(),
                  action: () => showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          // title: Text("Alert Dialog Box"),
                          content: Text.rich(TextSpan(children: [
                            TextSpan(text: "eMart Driver App ".tr(), style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(
                                text: "collects location data of store and other places nearby to identify pickup and delivery locations even when the app is closed or not in use."
                                    .tr())
                          ])),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                              },
                              child: Text("Deny".tr()),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                goOnline(_driverModel!);
                              },
                              child: Text("Accept".tr()),
                            ),
                          ],
                        ),
                      )
                  // goOnline(user!),
                  ),
            ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    if (isDarkMode(context))
      _mapController?.setMapStyle('[{"featureType": "all","'
          'elementType": "'
          'geo'
          'met'
          'ry","stylers": [{"color": "#242f3e"}]},{"featureType": "all","elementType": "labels.text.stroke","stylers": [{"lightness": -80}]},{"featureType": "administrative","elementType": "labels.text.fill","stylers": [{"color": "#746855"}]},{"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#263c3f"}]},{"featureType": "poi.park","elementType": "labels.text.fill","stylers": [{"color": "#6b9a76"}]},{"featureType": "road","elementType": "geometry.fill","stylers": [{"color": "#2b3544"}]},{"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#9ca5b3"}]},{"featureType": "road.arterial","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.arterial","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "road.highway","elementType": "geometry.fill","stylers": [{"color": "#746855"}]},{"featureType": "road.highway","elementType": "geometry.stroke","stylers": [{"color": "#1f2835"}]},{"featureType": "road.highway","elementType": "labels.text.fill","stylers": [{"color": "#f3d19c"}]},{"featureType": "road.local","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.local","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "transit","elementType": "geometry","stylers": [{"color": "#2f3948"}]},{"featureType": "transit.station","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "water","elementType": "geometry","stylers": [{"color": "#17263c"}]},{"featureType": "water","elementType": "labels.text.fill","stylers": [{"color": "#515c6d"}]},{"featureType": "water","elementType": "labels.text.stroke","stylers": [{"lightness": -20}]}]');
  }

  showDriverBottomSheet(User user) async {
    if (canShowSheet) {
      canShowSheet = false;
      await showModalBottomSheet(
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.transparent,
        context: context,
        builder: (context) {
          playSound();
          return WillPopScope(
            // ignore: missing_return
            onWillPop: () async => false,
            child: Padding(
              padding: EdgeInsets.all(15),
              child: Container(
                height: MediaQuery.of(context).size.height / 2.6,
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                decoration: BoxDecoration(
                  color: Color(0xff212121),
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    // crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          'New Parcel!'.tr(),
                          style: TextStyle(color: Color(0xffFFFFFF), fontFamily: "Poppinssb", letterSpacing: 0.5),
                        ),
                      ),
                      SizedBox(height: 5),


                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Trip Distance".tr(),
                                  style: TextStyle(color: Color(0xffADADAD), fontFamily: "Poppinsr", letterSpacing: 0.5),
                                ),
                                Text(
                                  // '0',
                                  "${user.orderParcelRequestData!.distance.toString()} km",
                                  style: TextStyle(color: Color(0xffFFFFFF), fontFamily: "Poppinsm", letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Expected Earning".tr(),
                                    style: TextStyle(color: Color(0xffADADAD), fontFamily: "Poppinsr", letterSpacing: 0.5),
                                  ),
                                  Text(
                                    // '0',
                                    "$symbol ${double.parse(user.orderParcelRequestData!.subTotal.toString()).toStringAsFixed(decimal)}",
                                    style: TextStyle(color: Color(0xffFFFFFF), fontFamily: "Poppinsm", letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 5),
                      Card(
                        color: Color(0xffFFFFFF),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 10),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/images/location3x.png',
                                height: 55,
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 270,
                                    child: Text(
                                      "${user.orderParcelRequestData!.sender!.address} ",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Color(0xff333333), fontFamily: "Poppinsr", letterSpacing: 0.5),
                                    ),
                                  ),
                                  SizedBox(height: 22),
                                  SizedBox(
                                    width: 270,
                                    child: Text(
                                      "${user.orderParcelRequestData!.receiver!.address} ",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Color(0xff333333), fontFamily: "Poppinsr", letterSpacing: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height / 20,
                            width: MediaQuery.of(context).size.width / 2.5,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                backgroundColor: Color(0xff434242),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(5),
                                  ),
                                ),
                              ),
                              child: Text(
                                'Reject',
                                style: TextStyle(color: Color(0xffFFFFFF), fontFamily: "Poppinsm", letterSpacing: 0.5),
                              ),
                              onPressed: () async {
                                audioPlayer.stop();
                                if (_timer != null) {
                                  _timer!.cancel();
                                }
                                Navigator.pop(context);
                                showProgress(context, 'Rejecting order...'.tr(), false);
                                try {
                                  await rejectOrder(user);
                                  hideProgress();
                                } catch (e) {
                                  hideProgress();
                                  print('HomeScreenState.showDriverBottomSheet $e');
                                }
                              },
                            ),
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).size.height / 20,
                            width: MediaQuery.of(context).size.width / 2.5,
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                  backgroundColor: Color(COLOR_PRIMARY),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(5),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Accept'.tr(),
                                  style: TextStyle(color: Color(0xffFFFFFF), fontFamily: "Poppinsm", letterSpacing: 0.5),
                                ),
                                onPressed: () async {
                                  audioPlayer.stop();
                                  if (_timer != null) {
                                    _timer!.cancel();
                                  }
                                  Navigator.pop(context);
                                  showProgress(context, 'Accepting order...'.tr(), false);
                                  try {
                                    await acceptOrder(user);
                                    updateProgress('Finding the best route...'.tr());
                                    hideProgress();
                                    setState(() {});
                                  } catch (e) {
                                    hideProgress();
                                    print('HomeScreenState.showDriverBottomSheet $e');
                                  }
                                }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
      canShowSheet = true;
    }
  }

  acceptOrder(User user) async {
    print("user data ");
    log("user data 47 " + user.toString());
    ParcelOrderModel orderModel = user.orderParcelRequestData!;
    orderModel.status = ORDER_STATUS_DRIVER_ACCEPTED;
    orderModel.driverID = user.userID;

    Position? locationData = await getCurrentLocation();
    if (locationData != null) {
      user.location = UserLocation(latitude: locationData.latitude, longitude: locationData.longitude);
      user.geoFireData = GeoFireData(
          geohash: GeoFlutterFire().point(latitude: locationData.latitude, longitude: locationData.longitude).hash,
          geoPoint: GeoPoint(locationData.latitude, locationData.longitude));
    }
    orderModel.driver = user;
    await FireStoreUtils.updateParcelOrder(orderModel);

    user.orderParcelRequestData = null;
    user.inProgressOrderID = orderModel.id;

    MyAppState.currentUser = user;
    await FireStoreUtils.updateCurrentUser(user);
    await FireStoreUtils.sendFcmMessageSingle("Cab Driver Assigned.".tr(), user.firstName + " " + user.lastName + " will Pickup as soon as possible.", orderModel.author!.fcmToken);

    if (_driverModel!.inProgressOrderID != null) {
      getCurrentOrder();
    }
  }

  rejectOrder(User user) async {
    ParcelOrderModel orderModel = user.orderParcelRequestData!;
    orderModel.rejectedByDrivers!.add(user.userID);
    orderModel.status = ORDER_STATUS_DRIVER_REJECTED;
    await FireStoreUtils.updateParcelOrder(orderModel);
    user.orderParcelRequestData = null;
    MyAppState.currentUser = user;
    await FireStoreUtils.updateCurrentUser(user);
  }

  getDirections() async {
    if (currentOrder != null) {
      if (currentOrder!.status == ORDER_STATUS_SHIPPED) {
        List<LatLng> polylineCoordinates = [];

        PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
          GOOGLE_API_KEY,
          PointLatLng(_driverModel!.location.latitude, _driverModel!.location.longitude),
          PointLatLng(currentOrder!.senderLatLong!.latitude, currentOrder!.senderLatLong!.longitude),
          travelMode: TravelMode.driving,
        );

        print("----?${result.points}");
        if (result.points.isNotEmpty) {
          for (var point in result.points) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
        }
        setState(() {
          _markers.remove("Driver");
          _markers['Driver'] = Marker(
              markerId: const MarkerId('Driver'),
              infoWindow: const InfoWindow(title: "Driver"),
              position: LatLng(_driverModel!.location.latitude, _driverModel!.location.longitude),
              icon: taxiIcon!,
              rotation: double.parse(_driverModel!.rotation.toString()));
        });

        _markers.remove("Departure");
        _markers['Departure'] = Marker(
          markerId: const MarkerId('Departure'),
          infoWindow: const InfoWindow(title: "Departure"),
          position: LatLng(currentOrder!.senderLatLong!.latitude, currentOrder!.senderLatLong!.longitude),
          icon: departureIcon!,
        );

        _markers.remove("Destination");
        _markers['Destination'] = Marker(
          markerId: const MarkerId('Destination'),
          infoWindow: const InfoWindow(title: "Destination"),
          position: LatLng(currentOrder!.receiverLatLong!.latitude, currentOrder!.receiverLatLong!.longitude),
          icon: destinationIcon!,
        );
        addPolyLine(polylineCoordinates);
      } else if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT) {
        List<LatLng> polylineCoordinates = [];

        PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
          GOOGLE_API_KEY,
          PointLatLng(_driverModel!.location.latitude, _driverModel!.location.longitude),
          PointLatLng(currentOrder!.receiverLatLong!.latitude, currentOrder!.receiverLatLong!.longitude),
          travelMode: TravelMode.driving,
        );

        print("----?${result.points}");
        if (result.points.isNotEmpty) {
          for (var point in result.points) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
        }
        setState(() {
          _markers.remove("Driver");
          _markers['Driver'] = Marker(
              markerId: const MarkerId('Driver'),
              infoWindow: const InfoWindow(title: "Driver"),
              position: LatLng(_driverModel!.location.latitude, _driverModel!.location.longitude),
              icon: taxiIcon!,
              rotation: double.parse(_driverModel!.rotation.toString()));
        });
        _markers.remove("Departure");
        _markers['Departure'] = Marker(
          markerId: const MarkerId('Departure'),
          infoWindow: const InfoWindow(title: "Departure"),
          position: LatLng(currentOrder!.senderLatLong!.latitude, currentOrder!.senderLatLong!.longitude),
          icon: departureIcon!,
        );
        _markers.remove("Destination");
        _markers['Destination'] = Marker(
          markerId: const MarkerId('Destination'),
          infoWindow: const InfoWindow(title: "Destination"),
          position: LatLng(currentOrder!.receiverLatLong!.latitude, currentOrder!.receiverLatLong!.longitude),
          icon: destinationIcon!,
        );
        addPolyLine(polylineCoordinates);
      } else {
        List<LatLng> polylineCoordinates = [];

        PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
          GOOGLE_API_KEY,
          PointLatLng(currentOrder!.senderLatLong!.latitude, currentOrder!.senderLatLong!.longitude),
          PointLatLng(currentOrder!.receiverLatLong!.latitude, currentOrder!.receiverLatLong!.longitude),
          travelMode: TravelMode.driving,
        );

        if (result.points.isNotEmpty) {
          for (var point in result.points) {
            polylineCoordinates.add(LatLng(point.latitude, point.longitude));
          }
        }
        _markers.remove("Departure");
        _markers['Departure'] = Marker(
          markerId: const MarkerId('Departure'),
          infoWindow: const InfoWindow(title: "Departure"),
          position: LatLng(currentOrder!.senderLatLong!.latitude, currentOrder!.senderLatLong!.longitude),
          icon: departureIcon!,
        );
        _markers.remove("Destination");
        _markers['Destination'] = Marker(
          markerId: const MarkerId('Destination'),
          infoWindow: const InfoWindow(title: "Destination"),
          position: LatLng(currentOrder!.receiverLatLong!.latitude, currentOrder!.receiverLatLong!.longitude),
          icon: destinationIcon!,
        );
        addPolyLine(polylineCoordinates);
      }
    }
  }

  addPolyLine(List<LatLng> polylineCoordinates) {
    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      color: Color(COLOR_PRIMARY),
      points: polylineCoordinates,
      width: 4,
      geodesic: true,
    );
    polyLines[id] = polyline;
    setState(() {});
  }

  late Stream<ParcelOrderModel?> ordersFuture;
  ParcelOrderModel? currentOrder;

  late Stream<User> driverStream;
  User? _driverModel = User();

  getCurrentOrder() async {
    ordersFuture = FireStoreUtils().getParcelOrderByID(MyAppState.currentUser!.inProgressOrderID.toString());
    ordersFuture.listen((event) {
      print("------->${event!.status}");
      currentOrder = event;
      getDirections();
    });
  }

  getDriver() async {
    driverStream = FireStoreUtils().getDriver(MyAppState.currentUser!.userID);
    driverStream.listen((event) {
      setState(() => _driverModel = event);
      setState(() => MyAppState.currentUser = _driverModel);

      getDirections();
      if (_driverModel!.isActive) {
        if (_driverModel!.orderParcelRequestData != null) {
          showDriverBottomSheet(_driverModel!);
          startTimer(_driverModel!);
        }
      }
      if (_driverModel!.inProgressOrderID != null) {
        getCurrentOrder();
      }
    });
    await FireStoreUtils.firestore.collection(Setting).doc("DriverNearBy").get().then((value) {
      setState(() {
        minimumDepositToRideAccept = value.data()!['minimumDepositToRideAccept'];
      });
    });
  }

  Widget buildOrderActionsCard({pedding = 10, width = 60}) {
    bool isPickedUp = false;
    String? buttonText;
    if (currentOrder!.status == ORDER_STATUS_SHIPPED || currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED) {
      buttonText = 'Pick up Parcel'.tr();
      isPickedUp = true;
    } else if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT) {
      buttonText = 'Parcel delivery'.tr();
      isPickedUp = false;
    }
    return Container(
      margin: EdgeInsets.only(left: 8, right: 8),
      padding: EdgeInsets.symmetric(vertical: 15),
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(18)),
        color: isDarkMode(context) ? Color(0xff000000) : Color(0xffFFFFFF),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Visibility(
              visible: currentOrder!.paymentCollectByReceiver == true,
              child: Center(
                child: Text(
                  "Payment Collect by Receiver".tr(),
                  style: TextStyle(
                      fontSize: 16, color: isDarkMode(context) ? Color(0xffFFFFFF) : Color(0xff555555), fontFamily: "Poppinsr", fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
            ),
            if (currentOrder!.status == ORDER_STATUS_SHIPPED || currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED)
              Column(
                children: [
                  ListTile(
                    leading: Image.asset(
                      'assets/images/user3x.png',
                      height: 42,
                      width: 42,
                      color: Color(COLOR_PRIMARY),
                    ),
                    title: Text(
                      'Sender Name',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDarkMode(context) ? Color(0xffFFFFFF) : Color(0xff000000), fontFamily: "Poppinsm", letterSpacing: 0.5),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.sender!.name}'.tr(),
                        style: TextStyle(color: Color(0xff555555), fontSize: 12, fontFamily: "Poppinsr", letterSpacing: 0.5),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton.icon(
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6.0),
                                side: BorderSide(color: Color(0xff3DAE7D)),
                              ),
                              padding: EdgeInsets.zero,
                              minimumSize: Size(85, 30),
                              alignment: Alignment.center,
                              backgroundColor: Color(0xffFFFFFF),
                            ),
                            onPressed: () {
                              UrlLauncher.launch("tel://${currentOrder!.sender!.phone}");
                            },
                            icon: Image.asset(
                              'assets/images/call3x.png',
                              height: 14,
                              width: 14,
                            ),
                            label: Text(
                              "CALL".tr(),
                              style: TextStyle(color: Color(0xff3DAE7D), fontFamily: "Poppinsm", letterSpacing: 0.5),
                            )),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/user3x.png',
                      height: 42,
                      width: 42,
                      color: Color(COLOR_PRIMARY),
                    ),
                    title: Text(
                      'Receiver Name',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDarkMode(context) ? Color(0xffFFFFFF) : Color(0xff000000), fontFamily: "Poppinsm", letterSpacing: 0.5),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.receiver!.name}'.tr(),
                        style: TextStyle(color: Color(0xff555555), fontSize: 12, fontFamily: "Poppinsr", letterSpacing: 0.5),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton.icon(
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6.0),
                                side: BorderSide(color: Color(0xff3DAE7D)),
                              ),
                              padding: EdgeInsets.zero,
                              minimumSize: Size(85, 30),
                              alignment: Alignment.center,
                              backgroundColor: Color(0xffFFFFFF),
                            ),
                            onPressed: () {
                              UrlLauncher.launch("tel://${currentOrder!.receiver!.phone}");
                            },
                            icon: Image.asset(
                              'assets/images/call3x.png',
                              height: 14,
                              width: 14,
                            ),
                            label: Text(
                              "CALL".tr(),
                              style: TextStyle(color: Color(0xff3DAE7D), fontFamily: "Poppinsm", letterSpacing: 0.5),
                            )),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/user3x.png',
                      height: 42,
                      width: 42,
                      color: Color(COLOR_PRIMARY),
                    ),
                    title: Text(
                      '${currentOrder!.author!.shippingAddress.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDarkMode(context) ? Color(0xffFFFFFF) : Color(0xff000000), fontFamily: "Poppinsm", letterSpacing: 0.5),
                    ),
                    subtitle: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'ORDER ID '.tr(),
                            style: TextStyle(color: Color(0xff555555), fontSize: 12, fontFamily: "Poppinsr", letterSpacing: 0.5),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width / 4,
                            child: Text(
                              '${currentOrder!.id} ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: isDarkMode(context) ? Color(0xffFFFFFF) : Color(0xff000000), fontFamily: "Poppinsr", letterSpacing: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton.icon(
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6.0),
                                side: BorderSide(color: Color(0xff3DAE7D)),
                              ),
                              padding: EdgeInsets.zero,
                              minimumSize: Size(85, 30),
                              alignment: Alignment.center,
                              backgroundColor: Color(0xffFFFFFF),
                            ),
                            onPressed: () {
                              UrlLauncher.launch("tel://${currentOrder!.author!.phoneNumber}");
                            },
                            icon: Image.asset(
                              'assets/images/call3x.png',
                              height: 14,
                              width: 14,
                            ),
                            label: Text(
                              "CALL".tr(),
                              style: TextStyle(color: Color(0xff3DAE7D), fontFamily: "Poppinsm", letterSpacing: 0.5),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            SizedBox(
              height: 10,
            ),
            if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT)
              Column(
                children: [
                  ListTile(
                    leading: Image.asset(
                      'assets/images/user3x.png',
                      height: 42,
                      width: 42,
                      color: Color(COLOR_PRIMARY),
                    ),
                    title: Text(
                      'Sender Name',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDarkMode(context) ? Color(0xffFFFFFF) : Color(0xff000000), fontFamily: "Poppinsm", letterSpacing: 0.5),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.sender!.name}'.tr(),
                        style: TextStyle(color: Color(0xff555555), fontSize: 12, fontFamily: "Poppinsr", letterSpacing: 0.5),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton.icon(
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6.0),
                                side: BorderSide(color: Color(0xff3DAE7D)),
                              ),
                              padding: EdgeInsets.zero,
                              minimumSize: Size(85, 30),
                              alignment: Alignment.center,
                              backgroundColor: Color(0xffFFFFFF),
                            ),
                            onPressed: () {
                              UrlLauncher.launch("tel://${currentOrder!.sender!.phone}");
                            },
                            icon: Image.asset(
                              'assets/images/call3x.png',
                              height: 14,
                              width: 14,
                            ),
                            label: Text(
                              "CALL".tr(),
                              style: TextStyle(color: Color(0xff3DAE7D), fontFamily: "Poppinsm", letterSpacing: 0.5),
                            )),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/user3x.png',
                      height: 42,
                      width: 42,
                      color: Color(COLOR_PRIMARY),
                    ),
                    title: Text(
                      'Receiver Name',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDarkMode(context) ? Color(0xffFFFFFF) : Color(0xff000000), fontFamily: "Poppinsm", letterSpacing: 0.5),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.receiver!.name}'.tr(),
                        style: TextStyle(color: Color(0xff555555), fontSize: 12, fontFamily: "Poppinsr", letterSpacing: 0.5),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton.icon(
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6.0),
                                side: BorderSide(color: Color(0xff3DAE7D)),
                              ),
                              padding: EdgeInsets.zero,
                              minimumSize: Size(85, 30),
                              alignment: Alignment.center,
                              backgroundColor: Color(0xffFFFFFF),
                            ),
                            onPressed: () {
                              UrlLauncher.launch("tel://${currentOrder!.receiver!.phone}");
                            },
                            icon: Image.asset(
                              'assets/images/call3x.png',
                              height: 14,
                              width: 14,
                            ),
                            label: Text(
                              "CALL".tr(),
                              style: TextStyle(color: Color(0xff3DAE7D), fontFamily: "Poppinsm", letterSpacing: 0.5),
                            )),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/user3x.png',
                      height: 42,
                      width: 42,
                      color: Color(COLOR_PRIMARY),
                    ),
                    title: Text(
                      '${currentOrder!.author!.shippingAddress.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: isDarkMode(context) ? Color(0xffFFFFFF) : Color(0xff000000), fontFamily: "Poppinsm", letterSpacing: 0.5),
                    ),
                    subtitle: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'ORDER ID '.tr(),
                            style: TextStyle(color: Color(0xff555555), fontSize: 12, fontFamily: "Poppinsr", letterSpacing: 0.5),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width / 4,
                            child: Text(
                              '${currentOrder!.id} ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: isDarkMode(context) ? Color(0xffFFFFFF) : Color(0xff000000), fontSize: 12, fontFamily: "Poppinsr", letterSpacing: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton.icon(
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6.0),
                                side: BorderSide(color: Color(0xff3DAE7D)),
                              ),
                              padding: EdgeInsets.zero,
                              minimumSize: Size(85, 30),
                              alignment: Alignment.center,
                              backgroundColor: Color(0xffFFFFFF),
                            ),
                            onPressed: () {
                              UrlLauncher.launch("tel://${currentOrder!.author!.phoneNumber}");
                            },
                            icon: Image.asset(
                              'assets/images/call3x.png',
                              height: 14,
                              width: 14,
                            ),
                            label: Text(
                              "CALL".tr(),
                              style: TextStyle(color: Color(0xff3DAE7D), fontFamily: "Poppinsm", letterSpacing: 0.5),
                            )),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/delivery_location3x.png',
                      height: 42,
                      width: 42,
                      color: Color(COLOR_PRIMARY),
                    ),
                    title: Text(
                      'Destination'.tr(),
                      style: TextStyle(color: Color(0xff9091A4), fontFamily: "Poppinsr", letterSpacing: 0.5),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.receiver!.address}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: isDarkMode(context) ? Color(0xffFFFFFF) : Color(0xff333333), fontFamily: "Poppinsr", letterSpacing: 0.5),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton.icon(
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6.0),
                                side: BorderSide(color: Color(0xff3DAE7D)),
                              ),
                              padding: EdgeInsets.zero,
                              minimumSize: Size(100, 30),
                              alignment: Alignment.center,
                              backgroundColor: Color(0xffFFFFFF),
                            ),
                            onPressed: () => openChatWithCustomer(),
                            icon: Icon(
                              Icons.message,
                              size: 16,
                              color: Color(0xff3DAE7D),
                            ),
                            // Image.asset(
                            //   'assets/images/call3x.png',
                            //   height: 14,
                            //   width: 14,
                            // ),
                            label: Text(
                              "Message".tr(),
                              style: TextStyle(color: Color(0xff3DAE7D), fontFamily: "Poppinsm", letterSpacing: 0.5),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT) SizedBox(height: 25),
            isPickedUp
                ? FadeTransition(
                    opacity: _animationController!,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: AnimatedContainer(
                        duration: Duration(seconds: 2),
                        height: 40,
                        width: MediaQuery.of(context).size.width,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                            backgroundColor: Color(COLOR_PRIMARY),
                          ),
                          onPressed: () async {
                            if (currentOrder!.status == ORDER_STATUS_SHIPPED || currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED) {
                              completePickUp();
                            } else if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT) {
                              completeOrder();
                            }
                          },
                          child: Text(
                            buttonText ?? "",
                            style: TextStyle(color: Color(0xffFFFFFF), fontFamily: "Poppinsm", letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: AnimatedContainer(
                      duration: Duration(seconds: 2),
                      height: 40,
                      width: MediaQuery.of(context).size.width,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(4),
                            ),
                          ),
                          backgroundColor: Color(COLOR_PRIMARY),
                        ),
                        onPressed: () async {
                          if (currentOrder!.status == ORDER_STATUS_SHIPPED || currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED) {
                            completePickUp();
                          } else if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT) {
                            completeOrder();
                          }
                        },
                        child: Text(
                          buttonText ?? "",
                          style: TextStyle(color: Color(0xffFFFFFF), fontFamily: "Poppinsm", letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  completePickUp() async {
    final result = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => ParcelImagesShow(images: currentOrder!.parcelImages!)));

    if (result != null) {
      if (result == "pickup") {
        print('HomeScreenState.completePickUp');
        showProgress(context, 'Updating order...', false);
        currentOrder!.status = ORDER_STATUS_IN_TRANSIT;
        await FireStoreUtils.updateParcelOrder(currentOrder!);

        hideProgress();
        setState(() {});
      } else if (result == "orderCancel") {
        print('HomeScreenState.completePickUp');
        showProgress(context, 'Updating order...', false);
        currentOrder!.status = ORDER_STATUS_REJECTED;
        await FireStoreUtils.updateParcelOrder(currentOrder!);

        if (currentOrder!.paymentMethod.toLowerCase() != "cod") {
          double totalTax = 0.0;
          if (currentOrder!.taxType!.isNotEmpty) {
            if (currentOrder!.taxType == "percent") {
              totalTax = (double.parse(currentOrder!.subTotal.toString()) - double.parse(currentOrder!.discount.toString())) * double.parse(currentOrder!.tax.toString()) / 100;
            } else {
              totalTax = double.parse(currentOrder!.tax.toString());
            }
          }

          double subTotal = double.parse(currentOrder!.subTotal.toString()) - double.parse(currentOrder!.discount.toString());

          double userAmount = 0;

          if (currentOrder!.paymentMethod.toLowerCase() != "cod") {
            userAmount = subTotal + totalTax;
          }

          await FireStoreUtils.createPaymentId().then((value) async {
            final paymentID = value;
            await FireStoreUtils.topUpWalletAmount(userID: currentOrder!.authorID, paymentMethod: "Refund Amount", amount: userAmount, id: paymentID).then((value) async {
              await FireStoreUtils.updateUserWalletAmount(userId: currentOrder!.authorID, amount: userAmount).then((value) {});
            });
          });
        }

        Position? locationData = await getCurrentLocation();
        await FireStoreUtils.sendFcmMessage(
            "Order Rejected !".tr(), "${currentOrder!.driver!.firstName} ${currentOrder!.driver!.lastName} has reject your Parcel".tr(), currentOrder!.author!.fcmToken, null);

        MyAppState.currentUser!.location = UserLocation(latitude: locationData.latitude, longitude: locationData.longitude);
        MyAppState.currentUser!.geoFireData = GeoFireData(
            geohash: GeoFlutterFire().point(latitude: locationData.latitude, longitude: locationData.longitude).hash,
            geoPoint: GeoPoint(locationData.latitude, locationData.longitude));
        MyAppState.currentUser!.inProgressOrderID = null;
        currentOrder = null;
        await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
        _markers.clear();
        polyLines.clear();
        _mapController?.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: LatLng(locationData.latitude, locationData.longitude), zoom: 15),
          ),
        );

        hideProgress();
        setState(() {});
      }
    }
  }

  completeOrder() async {
    showProgress(context, 'Completing Delivery...'.tr(), false);
    currentOrder!.status = ORDER_STATUS_COMPLETED;
    updateParcelWalletAmount(currentOrder!);
    await FireStoreUtils.updateParcelOrder(currentOrder!);
    Position? locationData = await getCurrentLocation();
    await FireStoreUtils.sendFcmMessage("Order Complete".tr(), "Our Delivery agent delivered order.".tr(), currentOrder!.author!.fcmToken, null);
    await FireStoreUtils.getParcelFirstOrderOrNOt(currentOrder!).then((value) async {
      if (value == true) {
        await FireStoreUtils.updateParcelReferralAmount(currentOrder!);
      }
    });
    _driverModel!.inProgressOrderID = null;
    _driverModel!.location = UserLocation(latitude: locationData.latitude, longitude: locationData.longitude);
    _driverModel!.geoFireData =
        GeoFireData(geohash: GeoFlutterFire().point(latitude: locationData.latitude, longitude: locationData.longitude).hash, geoPoint: GeoPoint(locationData.latitude, locationData.longitude));

    await FireStoreUtils.updateCurrentUser(_driverModel!);
    hideProgress();
    _markers.clear();
    polyLines.clear();
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(locationData.latitude, locationData.longitude), zoom: 15),
      ),
    );
    setState(() {});
  }

  openChatWithCustomer() async {
    await showProgress(context, "Please wait".tr(), false);

    User? customer = await FireStoreUtils.getCurrentUser(currentOrder!.authorID);
    print(currentOrder!.driverID);
    User? driver = await FireStoreUtils.getCurrentUser(currentOrder!.driverID.toString());

    hideProgress();
    push(
        context,
        ChatScreens(
          customerName: customer!.firstName + " " + customer.lastName,
          restaurantName: driver!.firstName + " " + driver.lastName,
          orderId: currentOrder!.id,
          restaurantId: driver.userID,
          customerId: customer.userID,
          customerProfileImage: customer.profilePictureURL,
          restaurantProfileImage: driver.profilePictureURL,
          token: customer.fcmToken,
          chatType: 'Driver',
        ));
  }

  goOnline(User user) async {
    await showProgress(context, 'Going online...'.tr(), false);
    Position locationData = await getCurrentLocation();
    print('HomeScreenState.goOnline');
    user.isActive = true;
    if (locationData != null) {
      user.location = UserLocation(latitude: locationData.latitude, longitude: locationData.longitude);
      user.geoFireData = GeoFireData(
          geohash: GeoFlutterFire().point(latitude: locationData.latitude, longitude: locationData.longitude).hash,
          geoPoint: GeoPoint(locationData.latitude, locationData.longitude));
    }
    MyAppState.currentUser = user;
    await FireStoreUtils.updateCurrentUser(user);
    updateDriverOrder();
    await hideProgress();
  }

  curcy(CurrencyModel currency) {
    if (currency.isactive == true) {
      symbol = currency.symbol;
      isRight = currency.symbolatright;
      decimal = currency.decimal;
      return Center();
    }
    return Center();
  }

  final audioPlayer = AudioPlayer();
  bool isPlaying = false;

  playSound() async {
    final path = await rootBundle.load("assets/audio/mixkit-happy-bells-notification-937.mp3");
    audioPlayer.setSourceBytes(path.buffer.asUint8List());
    audioPlayer.setReleaseMode(ReleaseMode.loop);
    //audioPlayer.setSourceUrl(url);
    audioPlayer.play(BytesSource(path.buffer.asUint8List()),
        volume: 15,
        ctx: AudioContext(
            android:
                AudioContextAndroid(contentType: AndroidContentType.music, isSpeakerphoneOn: true, stayAwake: true, usageType: AndroidUsageType.alarm, audioFocus: AndroidAudioFocus.gainTransient),
            iOS: AudioContextIOS(category: AVAudioSessionCategory.playback, options: [])));
  }
}
