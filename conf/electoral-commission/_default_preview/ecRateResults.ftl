<#macro RateResults result="" rating="" email="" class="">
<#if rating == 'good'>
<#local linktitle = 'Yes - I found this search result helpful'>
<#else>
<#local linktitle = 'No - I did not find this search result helpful'>
</#if>
<a href="" title="${linktitle}" class="${class}"><#nested></a>
</#macro>