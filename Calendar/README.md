# Script createHtmlCalendar.psm1
This script creates HTML calendar views. It can be created over years, or one or several months at a time. You can also select a date range in the script, followed by marking by color. You can upload the received data to a file or use the received data when sending an email, for example, to notify the user about a vacation.
___
### Example 1:
```
CreateBigCalendar -beginDay 25.07.2023 -finishDay 07.08.2023 -OutFilePathForAllMount C:\path\vacation.html -fnResHighlight "True"
```
### Result:
![img1.jpg](https://github.com/KuleshovAnton/pwsh/blob/main/Calendar/img/img1.JPG)
___
### Example 2:
```
CreateBigCalendar -beginDay 01.01.2023 -finishDay 20.12.2023 -OutFilePathForAllMount C:\path\vacation.html
```
### Result:
![img2.jpg](https://github.com/KuleshovAnton/pwsh/blob/main/Calendar/img/img2.JPG)
