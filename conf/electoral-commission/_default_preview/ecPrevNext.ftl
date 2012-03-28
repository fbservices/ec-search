<#macro PrevNext>
    <#if response?exists && response.resultPacket?exists && response.resultPacket.resultsSummary?exists>
        <#local rs = response.resultPacket.resultsSummary />

        <#-- PREVIOUS link -->
        <#if rs.prevStart?exists>
            <#local url = question.collection.configuration.value("ui.modern.search_link") + "?" />
            <#local url = url + changeParam(QueryString, "start_rank", rs.prevStart) />

            <a href="${url?html}">&lt;&lt; Previous</a>
        </#if>

        <#local pages = 0 />
        <#if rs.fullyMatching &gt; 0>
            <#local pages = (rs.fullyMatching + rs.partiallyMatching + rs.numRanks - 1) / rs.numRanks />
        <#else>
            <#local pages = (rs.totalMatching + rs.numRanks - 1) / rs.numRanks />
        </#if>

        <#local currentPage = 1 />
        <#if rs.currStart &gt; 0 && rs.numRanks &gt; 0>
            <#local currentPage = (rs.currStart + rs.numRanks -1) / rs.numRanks />
        </#if>

        <#local firstPage = 1 />
        <#if currentPage &gt; 4>
            <#local firstPage = currentPage - 4 />
        </#if>

        <#list firstPage..firstPage+9 as pg>
            <#if pg &gt; pages><#break /></#if>

            <#if pg == currentPage>
                ${pg}&nbsp;
            <#else>
                <#local url = question.collection.configuration.value("ui.modern.search_link") + "?" />
                <#local url = url + changeParam(QueryString, "start_rank", (pg-1) * rs.numRanks+1) />

                <a href="${url?html}">${pg}</a>
            </#if>
        </#list>

        <#-- NEXT link -->
        <#if rs.nextStart?exists>
            <#local url = question.collection.configuration.value("ui.modern.search_link") + "?" />
            <#local url = url + changeParam(QueryString, "start_rank", rs.nextStart) />

            <a href="${url?html}">Next &gt;&gt;</a>
        </#if>
    </#if>
</#macro>                        