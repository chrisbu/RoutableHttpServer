#import("RoutableHttpServer.dart");

main() {
  RoutableHttpServer httpServer = new RoutableHttpServer();
  
  /* ADD SOME SAMPLE ROUTES */
  
  //   http://127.0.0.1:8080/hello?name=Dart
  httpServer.add("/hello", "GET", (req,res) {
    try {
      res.setHeader("Content-Type","text/plain");
      
      //grab the session object - just a simple map at present...
      Map<String,Object> session = httpServer.getSession(req);
      
      //if visitCount is not in session, then use zero, otherwise read from session.
      int visitCount = session["visitCount"] == null ? 0 : session["visitCount"];
      visitCount += 1;
      session["visitCount"] = visitCount;
      
      res.writeString("This is visit: ${visitCount}\n\n");
      
      String nameFromQueryString = req.queryParameters["name"];
      if (nameFromQueryString != null) {
        //update the session name from the query string
        httpServer.getSession(req)["name"] = nameFromQueryString;
        res.writeString("Hello ${nameFromQueryString} - you're stored in the session");
        res.writeString("\ntry removing ?name=${nameFromQueryString} from the url");
        res.writeString("\nto see if you are remembered by the session.");
      }
      else {
        //get the name from the session.
        String nameFromSession = httpServer.getSession(req)["name"];
        
        if (nameFromSession != null) {
          //no name on the query string and we have a name in the session...
          res.writeString("Welcome back, ${nameFromSession}");
        }
        else {
          res.writeString("Who are you? - try /hello?name=Chris");
        }  
      }
      
      
      //add some session info to the output
      
      
      res.writeString("\n\n--------------------\n");
      res.writeString("\nsessionid=" + session["session-id"]);
      res.writeString("\nfirst-accessed: " + session["first-accessed"]);
      res.writeString("\nlast-accessed: " + session["last-accessed"]);
      res.writeString("\n\n--------------------\n");
      res.writeString("\n- first-accessed should remain the same while");
      res.writeString("\n- last-accessed should update each time");
      
    }
    catch (Exception ex, var stack) {
      print(ex);
      print(stack);
    }
    finally {
      
      res.writeDone();  //TODO: Put in finally.
    }
  });
  
  
  httpServer.add("/clear", "GET", (req, res) {
    //clear ALL the session cookies 
    //for all sessions!
    httpServer.clearSessions(req,res);
    
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
 