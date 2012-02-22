  

#import("RoutableHttpServer.dart");

main() {
  RoutableHttpServer httpServer = new RoutableHttpServer();
  
  /* ADD SOME SAMPLE ROUTES */
  
  //   http://127.0.0.1:8080/hello?name=Dart
  httpServer.add("/hello", "GET", (req,res) {
    try {
      String name = "";
      if (req.queryParameters.containsKey("name")) {
        name = req.queryParameters["name"]; 
        res.writeString("Hello ${name}");
      }
      else {
        res.writeString("Who are you? - try /hello?name=Chris");  
      }
    }
    finally {
      res.writeDone();  //TODO: Put in finally.
    }
  });
  
  
  //   http://127.0.0.1:8080/exception
  httpServer.add("/exception", "GET", (req,res) {
    res.foo(); //will throw a noSuchMethod exception
  });
  
  //will serve any files in the current folder "." 
  //when called with a url such as http://127.0.0.1:8080/static/myfile.html
  //   http://127.0.0.1:8080/static/http.dart
  httpServer.addStaticFileHandler("/static", ".");
  
  
  
  //Start listening
  httpServer.go("127.0.0.1",8080);
}
 