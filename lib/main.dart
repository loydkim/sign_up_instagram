import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:signupinstagram/youtubepromotion.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sign Up with Instagram',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  
  // Your Instagram config information in facebook developer site.
  static final  String appId = 'YOUR_INSTAGRAM_APP_ID'; //ex 202181494449441
  static final  String appSecret = 'YOUR_INSTAGRAM_APP_SECRET'; //ex ec0660294c82039b12741caba60f440c
  static final String redirectUri = 'YOUR_REDIRECT_URL'; //ex https://github.com/loydkim
  static final String initialUrl = 'https://api.instagram.com/oauth/authorize?client_id=$appId&redirect_uri=$redirectUri&scope=user_profile,user_media&response_type=code';
  final authFunctionUrl = 'YOUR_FIREBASE_FUNCTION_MAKE_CUSTOM_TOEKN_URL'; //ex https://us-central1-signuptest-beb58.cloudfunctions.net/makeCustomToken
  
  // Variable for UI.
  bool _showInstagramSingUpWeb = false;
  num _stackIndex = 1;
  dynamic _userData;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Scaffold(appBar: AppBar(title: Text('Sign Up with Instagram.')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _userData != null ?
                Column(
                  children: <Widget>[
                    Container(
                        width:120,height: 120,
                        child: Image.asset('images/instagramlogo.png')
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Name: ${_userData['username']}\nId: ${_userData['id']}\nmedia_count: ${_userData['media_count']}\naccount_type: ${_userData['account_type']}',style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
                    )
                  ],
                ) :
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GestureDetector(
                      onTap: () { setState(() => _showInstagramSingUpWeb = true); },
                      child: Container(
                          width:220,height: 220,
                          child: Image.asset('images/instagramlogo.png')
                      )
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: RaisedButton(
                      shape: RoundedRectangleBorder(
                        borderRadius: new BorderRadius.circular(12.0),
                      ),
                      padding: EdgeInsets.all(16),
                      textColor: Colors.white,
                      color: _userData != null ? Colors.black : Colors.purple[600],
                      onPressed: () => _userData != null ? _logOut() : setState(() => _showInstagramSingUpWeb = true),
                      child: Text(_userData != null ? 'Log Out' : 'Instagram Log In', style: TextStyle(fontSize: 20),),
                    ),
                  ),
                ),
                youtubePromotion()
              ],
            ),
          ),
        ),
        _showInstagramSingUpWeb ? Positioned(
          child: Scaffold(
            body:IndexedStack(
              index: _stackIndex,
              children: <Widget>[
                WebView(
                  initialUrl: initialUrl,
                  navigationDelegate: (NavigationRequest request) {
                    if(request.url.startsWith(redirectUri)){
                      if(request.url.contains('error')) print('the url error');
                      var startIndex = request.url.indexOf('code=');
                      var endIndex = request.url.lastIndexOf('#');
                      var code = request.url.substring(startIndex + 5,endIndex);
                      _logIn(code);
                      return NavigationDecision.prevent;
                    }
                    return NavigationDecision.navigate;
                  },
                  onPageStarted: (url) => print("Page started " + url),
                  javascriptMode: JavascriptMode.unrestricted,
                  gestureNavigationEnabled: true,
                  initialMediaPlaybackPolicy: AutoMediaPlaybackPolicy.always_allow,
                  onPageFinished: (url) => setState(() => _stackIndex = 0),
                ),
                Center(child: Text('Loading open web page ...')),
                Center(child: Text('Creating Profile ...'))
              ],
            ),
          ),
        ) : Container()
      ],
    );
  }

  Future<void> _logOut() async {
    await FirebaseAuth.instance.signOut();
    setState(() => _userData = null);
  }

  Future<void>  _logIn(String code) async {
    setState(() => _stackIndex = 2);

    try {
      // Step 1. Get user's short token using facebook developers account information
      // Http post to Instagram access token URL.
      final http.Response response = await http.post(
          "https://api.instagram.com/oauth/access_token",
          body: {
            "client_id": appId,
            "redirect_uri": redirectUri,
            "client_secret": appSecret,
            "code": code,
            "grant_type": "authorization_code"
          });

      // Step 2. Change Instagram Short Access Token -> Long Access Token.
      final http.Response responseLongAccessToken = await http.get(
          'https://graph.instagram.com/access_token?grant_type=ig_exchange_token&client_secret=$appSecret&access_token=${json.decode(response.body)['access_token']}');

      // Step 3. Take User's Instagram Information using LongAccessToken
      final http.Response responseUserData = await http.get(
          'https://graph.instagram.com/${json.decode(response.body)['user_id'].toString()}?fields=id,username,account_type,media_count&access_token=${json.decode(responseLongAccessToken.body)['access_token']}');

      // Step 4. Making Custom Token For Firebase Authentication using Firebase Function.
      final http.Response responseCustomToken = await http.get(
          '$authFunctionUrl?instagramToken=${json.decode(responseUserData.body)['id']}');

      // Step 5. Sign Up with Custom Token.
      await FirebaseAuth.instance.signInWithCustomToken(token: json.decode(responseCustomToken.body)['customToken']).then((AuthResult _authResult){
        print('success auth with custom Token');
      }).catchError((error){
        print('Unable to sign in using custom token');
      });

      // Step 6. Save user data to Firebase database.
      await Firestore.instance.collection('users').document(json.decode(responseUserData.body)['id']).setData({
        'id':json.decode(responseUserData.body)['id'],
        'username':json.decode(responseUserData.body)['username'],
        'account_type':json.decode(responseUserData.body)['account_type'],
        'media_count':json.decode(responseUserData.body)['media_count'],
        'customToken':json.decode(responseCustomToken.body)['customToken']
      });

      // Change the variable status.
      setState(() {
        _userData = json.decode(responseUserData.body);
        _stackIndex = 1;
        _showInstagramSingUpWeb = false;
      });
    }catch(e) {
      print(e.toString());
    }
  }
}
