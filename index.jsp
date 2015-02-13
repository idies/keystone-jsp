<%@ page import="org.apache.http.client.methods.*" %>
<%@ page import="org.apache.http.impl.client.*" %>
<%@ page import="org.apache.http.entity.*" %>
<%@ page import="org.apache.http.*" %>
<%@ page import="org.apache.http.util.*" %>
<%@ page import="org.json.simple.*" %> 
<%@ page import="org.json.simple.parser.*" %> 

<%
  String SERVICE_USER = application.getInitParameter("SERVICE_USER");
  String SERVICE_PROJECT = application.getInitParameter("SERVICE_PROJECT");
  String SERVICE_PASSWORD = application.getInitParameter("SERVICE_PASSWORD");
  String KEYSTONE_URL = application.getInitParameter("KEYSTONE_URL");
  String CASJOBS_URL = application.getInitParameter("CASJOBS_URL");
  String PORTAL_URL = application.getInitParameter("PORTAL_URL");
  
  String userName = null;
    
  String token = request.getParameter("token");

  if (token == null || token.isEmpty()) {
    Cookie[] cookies = request.getCookies();
    if (cookies != null) {
      for (Cookie cookie : cookies) {
        if ("token".equals(cookie.getName())) {
          token = cookie.getValue();
          break;
        }
      }
    }
  }
    
  String postBody = 
"{\"auth\": {\"identity\": {\"methods\": [\"password\"],\"password\": {"+
"\"user\": {\"name\": \""+SERVICE_USER+"\",\"password\": \""+SERVICE_PASSWORD+"\",\"domain\": {"+
"\"id\": \"default\"}}}},\"scope\": {\"project\": {\"name\": \""+SERVICE_PROJECT+"\","+
"\"domain\": {\"id\": \"default\"}}}}}"; 
    
  String serviceToken = null;
    
  boolean tokenValidated = false;
  if (token != null && !token.isEmpty()) {
    try {
      CloseableHttpClient httpClient = HttpClients.createDefault();
      HttpPost httpPost = new HttpPost(KEYSTONE_URL+"/v3/auth/tokens");
      httpPost.setHeader("Content-Type","application/json");
      httpPost.setEntity(new StringEntity(postBody));
      CloseableHttpResponse httpResponse = httpClient.execute(httpPost);
      
      try {
        int code = httpResponse.getStatusLine().getStatusCode();
        Header[] headers = httpResponse.getAllHeaders();
        for (Header header : headers) {
          if("X-Subject-Token".equals(header.getName())) {
            serviceToken = header.getValue();
            break;
          }
        }
      } finally {
        httpResponse.close();
      }
        
      HttpGet httpGet = new HttpGet(KEYSTONE_URL+"/v3/auth/tokens");
      httpGet.setHeader("X-Auth-Token",serviceToken);
      httpGet.setHeader("X-Subject-Token",token);
        
      httpResponse = httpClient.execute(httpGet);
      try {
        int code = httpResponse.getStatusLine().getStatusCode();
        String responseBody = EntityUtils.toString(httpResponse.getEntity());
        JSONObject json = (JSONObject)new JSONParser().parse(responseBody);
        JSONObject tokenJson = (JSONObject)json.get("token");
        JSONObject userJson = (JSONObject)tokenJson.get("user");
        userName = userJson.get("name").toString();
      } finally {
        httpResponse.close();
      }
        
      tokenValidated = true;
    }
    catch (Exception ex) {}
    
  }
    
  boolean signedIn = !(token == null || token.isEmpty()) && tokenValidated;
    
  if (signedIn) {
    response.addCookie(new Cookie("token",token));
  }
  else {
    Cookie cookie = new Cookie("token","");
    cookie.setMaxAge(0);
    response.addCookie(cookie);
  }
%>
  
<!DOCTYPE html>
<html>
<head>
  <script src="http://code.jquery.com/jquery-1.11.2.min.js"></script>
  
  <script type="text/javascript">
    function signIn() {
      window.location.href = "<%=PORTAL_URL%>/?callbackUrl=" + encodeURIComponent(document.URL.replace(/token=[a-z0-9]*/g,""));
    }
    
    function signOut() {
      document.cookie = 'token=; expires=Thu, 01 Jan 1970 00:00:01 GMT;';
      window.location.href = "<%=PORTAL_URL%>/?logout=true";
    }
    
    function submitQuery() {      
      var match = document.cookie.match(new RegExp(name + '=([^;]+)'));
      var token = match[1];
      $.ajax({
        type: "POST",
        url: "<%=CASJOBS_URL%>/contexts/mydb/query",
        data: { 
          Query: document.getElementById("query").value 
        },
        headers: { 
          "X-Auth-Token": token 
        },
        success: function(results) {
          document.getElementById("results").value = results;
        }
      });
    }
  </script>
</head>
<body>
  <%
    if (signedIn) {
  %>    
      Signed in as <b><%=userName%></b>
      <br/>
      <input type="button" onclick="signOut()" value="Sign Out"/>
      <br/><br/>
      <textarea id="query" rows="10" cols="50">SELECT * FROM MyTable</textarea>
      <br/>
      <input type="button" onclick="submitQuery()" value="Submit"/>
      <br/><br/>
      <textarea id="results" readonly="true" rows="10" cols="50"></textarea>
  <%
    }
    else {
  %>
      <input type="button" onclick="signIn()" value="Sign In"/>
  <%
    }
  %>
</body>
</html>