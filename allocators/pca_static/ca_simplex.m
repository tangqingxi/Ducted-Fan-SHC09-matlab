function [y0, inB, e,itlim,errout] = ca_simplex(A,ct,b,inB,h,e,varargin)
% 来源：PCA/simplxuprevsol.m；独立副本，原文件未修改。

switch  length(varargin)
    case 0
    itlim = inf;
    [m,n] = size(A);
    case 1
    itlim = varargin{1};
    [m,n] = size(A);
    case 2
    itlim = inf;
    m = varargin{1};
    n = varargin{2};
    case 3
    itlim =varargin{3};
    m = varargin{1};
    n = varargin{2};
 end    	
    	
tol = 1e-10;

nind = 1:(n-m);

inD = setdiff(1:n, inB);

A(:,~e) = -A(:,~e);
ct(~e) = -ct(~e);
b = b + A(:,~e)*h(~e);

y0 = A(:,inB)\b;

done = false;
unbounded = false;

while (~done  || ~unbounded ) && (itlim > 0)
    itlim = itlim-1;

    lamt = ct(inB)/A(:,inB);
    rdt = ct(inD)-lamt*A(:,inD);
    [minr, qind] = min(rdt);
    if minr >=0
        done = true; %#ok<NASGU>
        break;
    end
    qel = inD(qind);
    yq = A(:,inB)\A(:,qel);
    
    if all(abs(yq)<=tol)
      unbounded = true;
      disp(' Solution is unbounded');
      break
    end


    rat = y0./yq; 
    
    hinB = h(inB);
    indm = yq<0;
    rat(indm) = rat(indm) - hinB(indm)./yq(indm);
    indz = abs(yq)<=tol;
    rat(indz) = inf;

    [minrat, p] = min(rat);

    if (abs(minrat) <= tol)
       indm = nind(rdt<0);
       qind = indm(1);
       qel = inD(qind);
       yq = A(:,inB)\A(:,qel);
       if all(abs(yq)<=tol)
           unbounded = true;
           disp(' Solution is unbounded');
           break
       end
       rat = y0./yq; 
        hinB = h(inB);
        indm = yq<0;
        rat(indm) = rat(indm) - hinB(indm)./yq(indm);
        indz = abs(yq)<=tol;
        rat(indz) = inf;

        [minrat, p] = min(rat);
    end

    if (minrat >= h(qel))
            e(qel) = ~e(qel);
            A(:,qel) = -A(:,qel);
             b = b + A(:,qel)*h(qel);
             ct(qel) = -ct(qel);
    elseif yq(p) > 0
           pel = inB(p);
           inB(p)= qel;
           inD(qind)= pel;
     else
            pel = inB(p);
            e(pel)=~e(pel);
            A(:,pel) = -A(:,pel);
            inB(p)= qel;
            inD(qind)= pel;
            ct(pel) = -ct(pel);
            b = b + A(:,pel)*h(pel);
     end
        
    y0 = A(:,inB)\b;
end
errout = unbounded;     
end
