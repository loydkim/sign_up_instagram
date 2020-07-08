const functions = require('firebase-functions');

var admin = require("firebase-admin");

var serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

exports.makeCustomToken = functions.https.onRequest(async (req, res) => {
  const instagramToken = req.query.instagramToken;

  admin.auth().createCustomToken(instagramToken)
  .then(function(customToken) {
    console.log(customToken);
    res.json({customToken: `${customToken}`});
  })
  .catch(function(error) {
    res.json({result: `makeCustomToken error`});
    console.log('Error creating custom token:', error);
  });

});
