#library("RoutableHttpServer");

#import("dart:io");

//would prefer to use this - but it doesn't work at the moment for dart vm
//#import("http://dart.googlecode.com/svn/branches/bleeding_edge/dart/samples/chat/http.dart");
#import("../../../../work/dart/dart-unstable-4349/dart/samples/chat/http.dart");


/**
* {req} is the request.
* {res} is the response.
* {onAsyncComplete} is a callback which MUST be called by the request handler
* function when it has finished executing.
*/
typedef HttpRequestHandlerFunction (HTTPRequest req, HTTPResponse);

class RoutableHttpServer extends HTTPServerImplementation {
  RoutableHttpServer() :  
    _routes = new Map<String, HttpRequestHandlerFunction>(),
    _sessions = new Map<String, Map<String,Object>>()
  {
    //default constructor
  }
  
  /**
  * When a request which matches the requestPath and method comes in, 
  * we will invoke the handler.
  */
  add(String requestPath, String method, HttpRequestHandlerFunction handler) {
    //TODO - CJB: Currently ignores the method 
    _routes[requestPath] = (req, res) => handler(req,res); 
  }
  
  /**
  * When a request which matches the requestPath comes in,
  * we will serve up a file with the matching name in the absoluteDiskFolder
  * Only works for "GET" method.
  */
  addStaticFileHandler(String requestPath, String absoluteDiskFolder) {
    //TODO - CJB: Make this only work for "GET" method
    _routes[requestPath] = (req, res) => _serveStaticFile(req.path, res, absoluteDiskFolder);
  }
  
  /**
  * Start listening...
  */
  go(String host, int port) {
    listen(host, port, _onConnection);
    print("Listening on ${host}:${port}");
  }
  
  clearSessions(req,HTTPResponse res) {
    _sessions = new Map<String, Map<String,Object>>();
    res.setHeader("Set-Cookie", "${SESSION_COOKIE}=;");
  }
  
  /**
  * return the session associated with the request.
  */
  Map<String,Object> getSession(HTTPRequest req) {
    //TODO - CJB: Fix this - it's fragile.
    
    //tempcookie takes precdence, as it's been added.
    String cookieHeader = req.headers["tempcookie"];
    if (cookieHeader == null) {
      //otherwise, look for a real cookie header.
      cookieHeader = req.headers["cookie"];
      if (cookieHeader != null) {
        print("found real cookie header: " + cookieHeader);
      }
    }
    else {
      print("tempCookieHeader=${cookieHeader}");
    }
    
    Map<String,Object> result = null;
    
    if (cookieHeader != null) {
      String sessionId = _extractSessionCookieId(cookieHeader);
      
      if (sessionId != null && _sessions.containsKey(sessionId) == true) {
        print("found sessionid=${sessionId} in sessions object");
        result = _sessions[sessionId];
      }
      else {
        print("sessionId=${sessionId} not found in sessions object");  
        //so we'll return null in the result.
      }
    }
    
    
    return result;
  }
  
  /**
  * get the session cookie Id from the header.
  */
  _extractSessionCookieId(String cookieHeader) {
    //TODO: fragile
    List<String> cookies = cookieHeader.split(";");
    String sessionid = null;
    for (String cookie in cookies) {
      String key = cookie.split("=")[0];
      if (key.contains(SESSION_COOKIE)) {
        sessionid = cookie.split("=")[1];
        break;
      }
    }
    
    return sessionid;
    
  }
  
  /**
  * when a connection is received, find the correct route by pattern matching
    and method.
    If we can't find a correct route, return 404
  */
  _onConnection(HTTPRequest req, HTTPResponse res) {
    //does the request path match any specific route in th map?
    print("${req.method}: ${req.path}");
    
    _checkSession(req,res); //adds or updates the session
    
    HttpRequestHandlerFunction handler = _findCorrectHandler(req.path, req.method);
    
    if (handler != null) {
      try {
        //call the handler
        handler(req,res);
      }
      catch (Exception ex, var stack) {
        //error 500
        _serverErrorHandler(ex,stack,res);
      }
    }
    else {
      //otherwise, 404
      _notFoundHandler(res);
      
    }
    
  }
  
  /**
  * Return the correct route handler
  */
  HttpRequestHandlerFunction _findCorrectHandler(String path, String method) {
    //very trivial implementation just to see if this works
    //TODO - CJB: should do proper pattern matching and also take account of the request method
    for (String key in _routes.getKeys()) {
      if (path.startsWith(key)) {
        //found, so return.
        print("found matching route key=${key} path=${path}");
        return _routes[key];
      }
    }
   
    //not found
    return null;
  }
  
  _serveStaticFile(String requestPath, HTTPResponse res, String absoluteDiskPath) {
    print("GET: static file: " + requestPath);
    //TODO - CJB: This is quick and dirty.  Better would be just to test if the
    //file requested actually existed.
    _getFileList(absoluteDiskPath,(List<String> fileList) {
      
      String requestedFile = requestPath.split("/").last();
      print("requestedFile: ${requestedFile}");
      
      bool fileFound = false;  
      for (String file in fileList) {
        
        if (file.endsWith(requestedFile)) {
          print("found file: ${file}");
          fileFound = true;
          
          //TODO - CJB: Change this to use file async
          File f = new File(file);
          
          RandomAccessFile raf = f.openSync();
          List buffer = new List(raf.lengthSync());
          raf.readListSync(buffer, 0, raf.lengthSync());
          print("closing file");
          raf.close();
          res.writeList(buffer, 0, buffer.length);
          
          //TODO - CJB: Try and guess the mime type by the extension.
          
        }
        else {
          //TODO: quick and dirty - get rid of.
          print("file ${file} doesn't end with ${requestedFile}");
        }
      }
      
      if (fileFound) {
        //TODO: should be in a finally
        res.writeDone();
      }
      else {
        _notFoundHandler(res);
      }
    });
  }
  
  /**
  * handle not found.
  */
  _notFoundHandler(HTTPResponseImplementation res) {
    //if not, then not found.
    res.statusCode = HTTPStatus.NOT_FOUND;
    res.setHeader("Content-Type", "text/plain");
    res.writeString("404 - Not found");
    res.writeDone();  //TODO: Put in a finally 
  }
  
  /**
  *  handle server error
  */
  _serverErrorHandler(ex,stack,HTTPResponseImplementation res) {
    res.statusCode = HTTPStatus.INTERNAL_SERVER_ERROR;
    res.setHeader("Content-Type", "text/plain");
    res.writeString("Exception: ${ex}");
    res.writeString("\n");
    res.writeString("Stack: ${stack}");
    res.writeDone(); //TODO: put in a finally
  }
  
  /**
  *  Adds a session cookie  
  */
  _checkSession(HTTPRequest req, HTTPResponse res) {
    String sessionid = null;
    boolean addSessionCookie = false;
    
    if (req.path.endsWith("favicon.ico")) {
      return;
    }
    
    //is there an existing session?
    Map<String,Object> session = getSession(req);
    print("session is null?=${session==null}");
    
    if (session == null) {
      print("adding session cookie");
      
      //is there an existing cookie header? 
      //if so, re-use the session cookie id...
      String cookieHeader = req.headers["cookie"];
      if (cookieHeader != null) {
        sessionid = _extractSessionCookieId(cookieHeader);
      }
      
      //if we can't extract the sessionId from the header...
      if (sessionid == null) {
        //generate a new ID.
        
        //this is a toy - don't use for real!
        sessionid = (Math.random() * Clock.now()).toInt().toString();    
      }

      //add a new session cookie.
      //no expiry means it will go when the browser session ends.
      res.setHeader("Set-Cookie","${SESSION_COOKIE}=${sessionid}; Path=/;");
      
      //add it into the request, too, as this is used later by the getSession() 
      //on the first pass, and it should take precedence over the cookie on the request.
      //TODO: change the cookie ID on the request. 
      req.headers.putIfAbsent("tempcookie", () => "${SESSION_COOKIE}=${sessionid}; Path=/;");
      //create somewhere to store stuff
      _sessions[sessionid] = new Map<String,Object>();
      
      //also store the session id in the session
      //this allows callers to get the session id.
      _sessions[sessionid]["session-id"] = sessionid; 
      print("Created Session: ${sessionid}");
      
      //add the time the session was first created
      _sessions[sessionid]["first-accessed"] = new Date.now();

    }
    else {
      print("there is already a session cookie");
    } 

    //add the time the last accessed the session (ie, now).
    getSession(req)["last-accessed"] = new Date.now(); 
    
    if (req.headers.containsKey("cookie")) {
      print("Header: cookie=${req.headers['cookie']}");
    }
    

  }
  
  /**
  * returns a list of files in the current folder
  */
  _getFileList(folder, onComplete) {
    List<String> result = new List<String>();
    
    Directory dir = new Directory(folder);
    dir.fileHandler = (fileName) {
      print(fileName);
      result.add(fileName);
    };
    
    dir.doneHandler = (value) {
      onComplete(result);
    };
    
    dir.errorHandler = (err) {
      print("Error: ${err}");
      onComplete(result);
    };
    
    dir.list();
    
  }
  
  //Contains the list of routes and handlers
  Map<String, HttpRequestHandlerFunction> _routes;
  Map<String,Map<String,Object>> _sessions;
  final String SESSION_COOKIE = "crumbs-i-am-a-cookie";
  final int NO_COOKIE_HEADER = 0;
  final int NO_SESSION_COOKIE = 1;
  final int INVALID_SESION_COOKE = 2;
  final int VALID_SESSION_COOKIE = 3;
}
